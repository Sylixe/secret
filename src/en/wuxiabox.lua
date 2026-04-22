-- {"id":788888888,"ver":"1.0.0","libVer":"1.0.0","author":"Sylixe"}

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

local POST = POST
local pageOfElem = pageOfElem

local GETDocument = GETDocument
local RequestDocument = RequestDocument
local FormBodyBuilder = FormBodyBuilder

local Novel = Novel
local NovelInfo = NovelInfo
local NovelChapter = NovelChapter

local function shrinkURL(longURL)
	return sub(longURL, 21)
end

local function expandURL(smallURL)
	return BASE_URL .. smallURL
end

-- Browse listings
local function parseBrowse(novelListURL)
	local doc = GETDocument(novelListURL)

	local novelList = doc:select(".novel-item > a")
	local listSize = novelList:size()

	local finalListArray = {}
	for i = 0, listSize - 1 do
		local novelInfo = novelList:get(i)

		local novelTitle = novelInfo:attr("title")
		local novelChapterCount = sub(novelInfo:selectFirst(".novel-stats > span"):text(), 6, -10)

		local finalNovelTitle
		if novelChapterCount ~= "" then
			finalNovelTitle = "(" .. novelChapterCount .. ") " .. novelTitle
		else
			finalNovelTitle = "(?) " .. novelTitle
		end

		finalListArray[i + 1] = Novel({
			title = finalNovelTitle,
			imageURL = expandURL(novelInfo:selectFirst(".cover-wrap > figure > img"):attr("data-src")),
			link = novelInfo:attr("href"),
		})
	end

	return finalListArray
end

local searchMap = {}

-- Search listings
local function search(filters)
	local query = tostring(filters[QUERY])
	local page = tonumber(filters[PAGE]) or 1
	if query == "" then
		return {}
	end

	local searchId = searchMap[query]
	if not searchId then
		local request = POST(
			SEARCH_REQUEST_URL,
			nil,
			FormBodyBuilder()
				:add("show", "title")
				:add("tempid", "1")
				:add("tbname", "news")
				:add("keyboard", query)
				:build()
		)

		local doc = RequestDocument(request)

		local selectedURL = doc:selectFirst(".pagination > a:nth-of-type(2)")

		if not selectedURL then
			return {}
		end

		local searchLink = selectedURL:attr("href")

		searchId = sub(searchLink, 44)
		searchMap[query] = searchId
	end

	return parseBrowse(expandURL("/e/search/result/index.php?page=" .. (page - 1) .. "&searchid=" .. searchId))
end

-- Helper
local function genreOrTagSelector(doc, section, finalTable)
	local genreList = doc:select(".categories > ul:nth-child(" .. section .. ") > li > a")
	local listSize = genreList:size()

	for i = 0, listSize - 1 do
		finalTable[i + 1] = genreList:get(i):text()
	end
end

-- Helper 2
local function extractChapters(doc, array, count)
	local list = doc:select(".chapter-list > li > a")
	local listSize = list:size()

	for j = 0, listSize - 1 do
		count = count + 1
		local chapter = list:get(j)
		array[count] = NovelChapter({
			order = count,
			title = chapter:selectFirst(".chapter-title"):text(),
			link = chapter:attr("href"),
		})
	end

	return count
end

-- Novel page
local function parseNovel(novelURL, loadChapters)
	local doc = GETDocument(expandURL(novelURL))

	local novelTitle = doc:selectFirst(".novel-title"):text()
	local novelImage = expandURL(doc:selectFirst(".cover > img"):attr("data-src"))
	local novelDescription =
		sub(gsub(gsub(gsub(doc:selectFirst(".content"):text(), "<br>", "\n"), "<p>", ""), "</p>", "\n"), 1, -2)
	local novelChapterCount = doc:selectFirst(".header-stats > span > strong"):text()
	local novelStatusString = doc:selectFirst(".header-stats > span:nth-child(2) > strong"):text()
	local novelStatus = STATUS_PICKER[novelStatusString]
	local novelTags = {}
	genreOrTagSelector(doc, 2, novelTags)
	local novelGenres = {}
	genreOrTagSelector(doc, 1, novelGenres)
	local novelAuthors = { doc:selectFirst(".author > span:nth-child(2)"):text() }

	local finalNovelTitle
	if novelStatusString == "Ongoing" then
		finalNovelTitle = "(" .. novelChapterCount .. ") " .. novelTitle
	else
		finalNovelTitle = "[" .. novelChapterCount .. "] " .. novelTitle
	end

	local novelData = {
		title = finalNovelTitle,
		imageURL = novelImage,
		description = novelDescription,
		status = novelStatus,
		tags = novelTags,
		genres = novelGenres,
		authors = novelAuthors,
	}

	if loadChapters then
		local lastChapterSelector = doc:selectFirst(".pagination > li:last-child > a")
		if not lastChapterSelector then
			local chapterArray = {}
			local chapterCount = 0

			local listingDoc = GETDocument(CHAPTER_LISTINGS_URL .. "0&wjm=" .. sub(novelURL, 8, -6))
			extractChapters(listingDoc, chapterArray, chapterCount)

			novelData.chapters = chapterArray
		else
			local lastChapterURL = lastChapterSelector:attr("href")
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
	local doc = GETDocument(expandURL(chapterURL))

	local chap = doc:selectFirst(".chapter-content")
	local title = doc:selectFirst(".chapter-header h2"):text()
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
		local genreIndex = tonumber(filters[GENRE_SELECT]) or 0
		local statusIndex = tonumber(filters[STATUS_SELECT]) or 0
		local sortByIndex = tonumber(filters[SORT_BY_SELECT]) or 0

		local currentPage = (tonumber(filters[PAGE]) or 1) - 1

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
	imageURL = "https://sylixe.github.io/secret/icons/wuxiabox.png",

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
