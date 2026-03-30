-- {"id":788888888,"ver":"1.0.1","libVer":"1.0.0","author":"Sylixe"}

local GENRE_LIST = {
	"All",
	"Action",
	"Adventure",
	"Chinese",
	"Comedy",
	"Contemporary Romance",
	"Drama",
	"Eastern Fantasy",
	"Erciyuan",
	"Faloo",
	"Fan-Fiction",
	"Fantasy",
	"Fantasy Romance",
	"Game",
	"Gender Bender",
	"Harem",
	"Hentai",
	"Historical",
	"Horror",
	"Isekai",
	"Japanese",
	"Josei",
	"Lolicon",
	"Magic",
	"Magical Realism",
	"Martial Arts",
	"Mecha",
	"Military",
	"Mystery",
	"Official Circles",
	"Psychological",
	"Romance",
	"School Life",
	"Sci-fi",
	"Science Fiction",
	"Seinen",
	"Shoujo",
	"Shoujo Ai",
	"Shounen",
	"Shounen Ai",
	"Slice of Life",
	"Sports",
	"Supernatural",
	"Suspense Thriller",
	"Tragedy",
	"Travel Through Time",
	"Two-dimensional",
	"Urban",
	"Urban Life",
	"Video Games",
	"Virtual Reality",
	"Wuxia",
	"Wuxia Xianxia",
	"Xianxia",
	"Xuanhuan",
	"Yaoi",
	"Yuri",
}

local STATUS_LIST = {
	"All",
	"Completed",
	"Ongoing",
}

local SORT_BY_LIST = {
	"New",
	"Popular",
	"Updates",
}

local STATUS_PICKER = {
	Ongoing = NovelStatus.PUBLISHING,
	Completed = NovelStatus.COMPLETED,
}

local QUERY = 0
local PAGE = 1
local GENRE_SELECT = 2
local STATUS_SELECT = 3
local SORT_BY_SELECT = 4

local BASE_URL = "https://www.wuxiabox.com"
local CHAPTER_LISTINGS_URL = "https://www.wuxiabox.com/e/extend/fy.php?page="
local SEARCH_REQUEST_URL = "https://www.wuxiabox.com/e/search/index.php"

local gsub = string.gsub
local sub = string.sub
local find = string.find
local tostring = tostring

local POST = POST
local pageOfElem = pageOfElem

local GETDocument = GETDocument
local RequestDocument = RequestDocument
local FormBodyBuilder = FormBodyBuilder

local Novel = Novel
local NovelInfo = NovelInfo
local NovelChapter = NovelChapter

local select, selectFirst, attr, text
local size, get
local fBuild, fAdd
do
	local temp = FormBodyBuilder()
	fBuild = temp.build
	fAdd = temp.add
end

local function shrinkURL(longURL)
	return sub(longURL, 21)
end

local function expandURL(smallURL)
	return BASE_URL .. smallURL
end

-- Browse listings
local function parseBrowse(novelListURL)
	local doc = GETDocument(novelListURL)

	if not select then
		selectFirst = doc.selectFirst
		select = doc.select
		attr = doc.attr
		text = doc.text
	end

	local novelList = select(doc, ".novel-item > a")

	if not size then
		size = novelList.size
		get = novelList.get
	end

	local listSize = size(novelList)

	local finalListArray = {}
	for i = 0, listSize - 1 do
		local novelInfo = get(novelList, i)

		finalListArray[i + 1] = Novel({
			title = attr(novelInfo, "title"),
			imageURL = expandURL(attr(selectFirst(novelInfo, ".cover-wrap > figure > img"), "data-src")),
			link = attr(novelInfo, "href"),
		})
	end

	return finalListArray
end

local searchMap = {}

-- Search listings
local function search(filters)
	local query = filters[QUERY]
	local page = filters[PAGE]
	if query == "" then
		return {}
	end

	local searchId = searchMap[query]
	if not searchId then
		local request = POST(
			SEARCH_REQUEST_URL,
			nil,
			fBuild(
				fAdd(
					fAdd(fAdd(fAdd(FormBodyBuilder(), "show", "title"), "tempid", "1"), "tbname", "news"),
					"keyboard",
					query
				)
			)
		)

		local doc = RequestDocument(request)

		local searchLink = attr(selectFirst(doc, ".pagination > a:nth-of-type(2)"), "href")

		searchId = sub(searchLink, 44)
		searchMap[query] = searchId
	end

	return parseBrowse(expandURL("/e/search/result/index.php?page=" .. (page - 1) .. "&searchid=" .. searchId))
end

-- Helper
local function genreOrTagSelector(doc, section, finalTable)
	local genreList = select(doc, ".categories > ul:nth-of-type(" .. tostring(section) .. ") > li > a")
	local listSize = size(genreList)

	for i = 0, listSize - 1 do
		finalTable[i + 1] = text(get(genreList, i))
	end
end

-- Helper 2
local function extractChapters(doc, array, count)
	local list = select(doc, ".chapter-list > li > a")
	local listSize = size(list)
	for j = 0, listSize - 1 do
		count = count + 1
		local chapter = get(list, j)
		array[count] = NovelChapter({
			order = count,
			title = text(selectFirst(chapter, ".chapter-title")),
			link = attr(chapter, "href"),
		})
	end
	return count
end

-- Novel page
local function parseNovel(novelURL, loadChapters)
	local doc = GETDocument(expandURL(novelURL))

	local novelTitle = text(selectFirst(doc, ".novel-title"))
	local novelImage = expandURL(attr(selectFirst(doc, ".cover > img"), "data-src"))
	local novelDescription =
		sub(gsub(gsub(gsub(text(selectFirst(doc, ".content")), "<br>", "\n"), "<p>", ""), "</p>", "\n"), 1, -2)
	local novelStatus = STATUS_PICKER[text(selectFirst(doc, ".header-stats > span:nth-of-type(2) > strong"))]
	local novelTags = {}
	genreOrTagSelector(doc, 2, novelTags)
	local novelGenres = {}
	genreOrTagSelector(doc, 1, novelGenres)
	local novelAuthor = { text(selectFirst(doc, ".author > span:nth-of-type(2)")) }

	local novelData = {
		title = novelTitle,
		imageURL = novelImage,
		description = novelDescription,
		status = novelStatus,
		tags = novelTags,
		genres = novelGenres,
		authors = novelAuthor,
	}

	if loadChapters then
		local lastChapterSelector = selectFirst(doc, ".pagination > li:last-child > a")
		if not lastChapterSelector then
			local chapterArray = {}
			local chapterCount = 0

			local listingDoc = GETDocument(CHAPTER_LISTINGS_URL .. "0&wjm=" .. sub(novelURL, 8, -6))
			extractChapters(listingDoc, chapterArray, chapterCount)

			novelData.chapters = chapterArray
		else
			local lastChapterURL = attr(lastChapterSelector, "href")
			local novelID, lastPageNumer
			do
				local ampersandLocation = find(lastChapterURL, "&", 23, true)
				novelID = sub(lastChapterURL, ampersandLocation)
				lastPageNumer = sub(lastChapterURL, 23, ampersandLocation - 1)
			end

			local chapterArray = {}
			local chapterCount = 0

			for i = 0, lastPageNumer do
				local listingDoc = GETDocument(CHAPTER_LISTINGS_URL .. i .. novelID)
				chapterCount = extractChapters(listingDoc, chapterArray, chapterCount)
			end

			novelData.chapters = chapterArray
		end
	end

	return NovelInfo(novelData)
end

-- Reader page
local function getPassage(chapterURL)
	local document = GETDocument(expandURL(chapterURL))
	local chap = selectFirst(document, ".chapter-content")
	local title = text(selectFirst(document, ".chapter-header h2"))
	chap:prepend("<h1>" .. title .. "</h1>")
	return pageOfElem(chap, true)
end

local filterModel = {
	DropdownFilter(GENRE_SELECT, "Genre", GENRE_LIST),
	DropdownFilter(STATUS_SELECT, "Status", STATUS_LIST),
	DropdownFilter(SORT_BY_SELECT, "Sort By", SORT_BY_LIST),
}

local listings = {
	Listing("Only", true, function(filters)
		local genreIndex = filters[GENRE_SELECT]
		local statusIndex = filters[STATUS_SELECT]
		local sortByIndex = filters[SORT_BY_SELECT]

		local currentPage = filters[PAGE] - 1

		local finalGenre = "All"
		local finalStatus = "all"
		local finalSortBy = "newstime"
		if genreIndex ~= nil and genreIndex ~= 0 then
			finalGenre = GENRE_LIST[genreIndex + 1]
		end
		if statusIndex ~= nil and statusIndex ~= 0 then
			finalStatus = STATUS_LIST[statusIndex + 1]
		end
		if sortByIndex ~= nil and sortByIndex ~= 0 then
			if sortByIndex == 1 then
				finalSortBy = "onclick"
			else
				finalSortBy = "lastdotime"
			end
		end

		return parseBrowse(
			expandURL(
				"/list/" .. finalGenre .. "/" .. finalStatus .. "-" .. finalSortBy .. "-" .. currentPage .. ".html"
			)
		)
	end),
}

local finalTable = {
	id = 788888888,
	name = "WuxiaBox",
	baseURL = BASE_URL,
	imageURL = "",

	hasSearch = true,
	hasCloudFlare = true,
	isSearchIncrementing = true,

	chapterType = ChapterType.HTML,

	listings = listings,
	searchFilters = filterModel,

	search = search,
	parseNovel = parseNovel,
	getPassage = getPassage,
	shrinkURL = shrinkURL,
	expandURL = expandURL,
}

-- Return extension table
return finalTable
