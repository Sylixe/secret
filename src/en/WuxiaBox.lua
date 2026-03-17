-- {"id":788888888,"ver":"1.0.0","libVer":"1.0.0","author":"Sylixe"}
local GENRE_LIST = {
	"All",
	"Fan-Fiction",
	"Faloo",
	"Action",
	"Adventure",
	"Comedy",
	"Contemporary Romance",
	"Drama",
	"Eastern Fantasy",
	"Fantasy",
	"Fantasy Romance",
	"Gender Bender",
	"Harem",
	"Historical",
	"Horror",
	"Josei",
	"Lolicon",
	"Magical Realism",
	"Martial Arts",
	"Mecha",
	"Mystery",
	"Psychological",
	"Romance",
	"School Life",
	"Sci-fi",
	"Seinen",
	"Shoujo",
	"Shounen",
	"Shounen Ai",
	"Slice of Life",
	"Sports",
	"Supernatural",
	"Tragedy",
	"Video Games",
	"Wuxia",
	"Xianxia",
	"Xuanhuan",
	"Yaoi",
	"Two-dimensional",
	"Erciyuan",
	"Game",
	"Military",
	"Urban Life",
	"Yuri",
	"Chinese",
	"Japanese",
	"Hentai",
	"Isekai",
	"Magic",
	"Shoujo Ai",
	"Urban",
	"Virtual Reality",
	"Wuxia Xianxia",
	"Official Circles",
	"Science Fiction",
	"Suspense Thriller",
	"Travel Through Time",
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

local BASE_URL = "https://wuxiabox.com"
local CHAPTER_LISTINGS_URL = "https://wuxiabox.com/e/extend/fy.php?page="
local SEARCH_REQUEST_URL = "https://wuxiabox.com/e/search/index.php"

local gsub = string.gsub
local sub = string.sub
local find = string.find
local tostring = tostring

local GETDocument = GETDocument
local Document = Document

local Novel = Novel
local NovelInfo = NovelInfo
local NovelChapter = NovelChapter

local select, selectFirst

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
	end

	local novelList = select(doc, ".novel-item > a")
	local listSize = novelList:size()

	local finalListArray = {}
	for i = 0, listSize - 1 do
		local novelInfo = novelList:get(i)

		finalListArray[i + 1] = Novel({
			title = novelInfo:attr("title"),
			imageURL = expandURL(selectFirst(novelInfo, ".cover-wrap > figure > img"):attr("data-src")),
			link = novelInfo:attr("href"),
		})
	end

	return finalListArray
end

local searchMap = {}

local function selectLast(elements)
	return elements:get(elements:size() - 1)
end

-- Search listings
local function search(filters)
	local query = filters[QUERY]
	local page = filters[PAGE]
	if query ~= "" then
		local searchId = searchMap[query]
		if searchId ~= nil then
			return parseBrowse(expandURL("/e/search/result/index.php?page=" .. (page - 1) .. "&searchid=" .. searchId))
		else
			local request =
				POST("https://www.wuxiabox.com/e/search/index.php?show=title&tempid=1&tbname=news&keyboard=" .. query)
			local document = RequestDocument(request)

			local pages = document:select("ul.pagination a")
			if pages:size() > 0 then
				searchMap[query] = selectLast(pages):attr("href"):match(".*searchid=([0-9]*).*")
				searchId = searchMap[query]
				return parseBrowse(
					expandURL("/e/search/result/index.php?page=" .. (page - 1) .. "&searchid=" .. searchId)
				)
			else
				return {
					Novel({
						title = tostring(document),
						link = "",
						imageURL = "",
					}),
				}
			end
		end
	end

	return {}
end
-- local function search(filters)
-- 	local query = filters[QUERY]
-- 	local page = filters[PAGE]
-- 	if query == "" then
-- 		return {}
-- 	end

-- 	local searchId = searchMap[query]
-- 	if not searchId then
-- 		local request = POST(
-- 			SEARCH_REQUEST_URL,
-- 			nil,
-- 			fBuild(
-- 				fAdd(
-- 					fAdd(fAdd(fAdd(FormBodyBuilder(), "show", "title"), "tempid", "1"), "tbname", "news"),
-- 					"keyboard",
-- 					query
-- 				)
-- 			)
-- 		)

-- 		local doc = RequestDocument(request)
-- 		local searchLink = selectFirst(doc, ".pagination > a:nth-of-type(2)"):attr("href")

-- 		searchId = sub(searchLink, 48)
-- 		searchMap[query] = searchId
-- 	end

-- 	return parseBrowse(expandURL("/e/search/result/index.php?page=" .. (page - 1) .. "&searchid=" .. searchId))
-- end

-- Helper
local function genreOrTagSelector(doc, section, finalTable)
	local genreList = select(doc, ".categories > ul:nth-of-type(" .. tostring(section) .. ") > li > a")
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

	local novelTitle = selectFirst(doc, ".novel-title"):text()
	local novelImage = expandURL(selectFirst(doc, ".cover > img"):attr("data-src"))
	local novelDescription =
		sub(gsub(gsub(gsub(selectFirst(doc, ".content"):text() or "", "<br>", "\n"), "<p>", ""), "</p>", "\n"), 1, -2)
	local novelStatus = STATUS_PICKER[selectFirst(doc, ".header-stats > span:nth-of-type(2) > strong"):text()]
	local novelTags = {}
	genreOrTagSelector(doc, 2, novelTags)
	local novelGenres = {}
	genreOrTagSelector(doc, 1, novelGenres)
	local novelAuthor = { selectFirst(doc, ".author > span:nth-of-type(2)"):text() }

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
			local lastChapterURL = lastChapterSelector:attr("href")
			local novelID, lastPageNumer
			do
				local ampersandLocation = find(lastChapterURL, "&", 23, true)
				novelID = sub(lastChapterURL, ampersandLocation) -- + 5
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
	local title = selectFirst(document, ".chapter-header h2"):text()
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
	imageURL = "",

	hasSearch = true,
	hasCloudFlare = true,
	isSearchIncrementing = true,

	chapterType = ChapterType.HTML,

	baseURL = BASE_URL,
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
