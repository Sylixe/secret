-- {"id":777888888,"ver":"1.0.0","libVer":"1.0.0","author":"Sylixe"}

local LISTING_LIST = {
	"Newest",
	"Latest",
	"Popular",
	"Completed",
}

local GENRE_LIST = {
	"None",
	"Action",
	"Adult",
	"Adventure",
	"Anime & Comics",
	"Comedy",
	"Drama",
	"Eastern",
	"Ecchi",
	"Fan-Fiction",
	"Fantasy",
	"Game",
	"Gender Bender",
	"Harem",
	"Historical",
	"Horror",
	"Isekai",
	"Josei",
	"LGBT+",
	"LitRPG",
	"Magic",
	"Magical Realism",
	"Martial Arts",
	"Mature",
	"Mecha",
	"Military",
	"Modern Life",
	"Mystery",
	"Other",
	"Psychological",
	"Reincarnation",
	"Romance",
	"School Life",
	"Sci-Fi",
	"Seinen",
	"Shoujo",
	"Shoujo Ai",
	"Shounen",
	"Shounen Ai",
	"Slice of Life",
	"Smut",
	"Sports",
	"Supernatural",
	"System",
	"Thriller",
	"Tragedy",
	"Urban",
	"Video Games",
	"War",
	"Wuxia",
	"Xianxia",
	"Xuanhuan",
	"Yaoi",
	"Yuri",
}

local STATUS_PICKER = {
	OnGoing = NovelStatus.PUBLISHING,
	Completed = NovelStatus.COMPLETED,
}

local SEARCH_MODE_LIST = {
	"Title",
	"Author",
}

local QUERY = 0
local PAGE = 1
local LISTING_SELECT = 2
local GENRE_SELECT = 3
local SEARCH_MODE_SELECT = 4

local BASE_URL = "https://freewebnovel.com"

local gsub = string.gsub
local match = string.match
local sub = string.sub
local tonumber = tonumber

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
	local doc
	if type(novelListURL) == "string" then
		doc = GETDocument(novelListURL)
	else
		doc = novelListURL
	end

	local titleAndLinkDocList = doc:select(".tit > a:not(.con)")
	local novelChapterCountDocList = doc:select(".right > a > span")
	local imageDocList = doc:select(".pic > a > img")

	local listSize = titleAndLinkDocList:size()

	local finalListArray = {}
	for i = 0, listSize - 1 do
		local titleDoc = titleAndLinkDocList:get(i)
		local chapterCountDoc = novelChapterCountDocList:get(i)
		local imageDoc = imageDocList:get(i)

		local novelChapterCount = match(chapterCountDoc:text(), "%d+") or "?"

		finalListArray[i + 1] = Novel({
			title = "(" .. novelChapterCount .. ") " .. titleDoc:attr("title"),
			imageURL = expandURL(imageDoc:attr("src")),
			link = titleDoc:attr("href"),
		})
	end

	return finalListArray
end

-- Search listings
local function search(filters)
	local searchMode = tonumber(filters[SEARCH_MODE_SELECT]) or 0
	local query = tostring(filters[QUERY])

	if query == "" then
		return {}
	end

	if searchMode == 0 then
		local request = POST("https://freewebnovel.com/search", nil, FormBodyBuilder():add("searchkey", query):build())
		local doc = RequestDocument(request)
		return parseBrowse(doc)
	else
		return parseBrowse("https://freewebnovel.com/author/" .. query)
	end
end

-- Novel page
local function parseNovel(novelURL, loadChapters)
	local doc = GETDocument(expandURL(novelURL))

	local novelTitle = doc:selectFirst(".m-desc > .tit"):text()
	local novelImage = expandURL(doc:selectFirst(".m-imgtxt > .pic"):attr("src"))
	local novelDescription =
		sub(gsub(gsub(gsub(doc:selectFirst(".txt > .inner"):text(), "<br>", "\n"), "<p>", ""), "</p>", "\n"), 1, -2)
	local novelStatusString = doc:selectFirst(".right > .s2 > a"):text()
	local novelStatus = STATUS_PICKER[novelStatusString]

	local buffer = doc:select(".right > a")
	local bufferSize = buffer:size()

	local novelAuthors = { buffer:get(0):attr("title") }
	local novelGenres = {}
	for i = 1, bufferSize - 1 do
		novelGenres[i] = buffer:get(i):text()
	end

	local finalNovelDescription = "Rating: " .. doc:selectFirst(".vote"):text() .. "\n" .. novelDescription

	local novelData = {
		imageURL = novelImage,
		description = finalNovelDescription,
		status = novelStatus,
		genres = novelGenres,
		authors = novelAuthors,
	}

	local novelChapterCount = "?"
	if loadChapters then
		local chapterDocList = doc:select(".m-newest2 > .ul-list5 > li > a")
		local listSize = chapterDocList:size()

		local chapterArray = {}
		for i = 0, listSize - 1 do
			local chapter = chapterDocList:get(i)
			local chapterTitle = chapter:attr("title")
			local chapterLink = chapter:attr("href")

			chapterArray[i + 1] = NovelChapter({
				order = i + 1,
				title = chapterTitle,
				link = chapterLink,
			})
		end

		novelChapterCount = #chapterArray
		novelData.chapters = chapterArray
	end

	local finalNovelTitle
	if novelStatusString == "OnGoing" then
		finalNovelTitle = "(" .. novelChapterCount .. ") " .. novelTitle
	else
		finalNovelTitle = "[" .. novelChapterCount .. "] " .. novelTitle
	end

	novelData.title = finalNovelTitle

	return NovelInfo(novelData)
end

-- Reader page
local function getPassage(chapterURL)
	local doc = GETDocument(expandURL(chapterURL))

	local chap = doc:selectFirst("#article")
	local title = doc:selectFirst(".chapter"):text()
	local hasExtraTitle = chap:selectFirst("h4")
	if hasExtraTitle ~= nil then
		hasExtraTitle:remove()
	end

	chap:select("div"):remove()
	chap:prepend("<h1>" .. title .. "</h1>")

	return pageOfElem(chap, true)
end

local function generatePlaceholder(buffer, title)
	local bufferSize = #buffer
	buffer[bufferSize + 1] = Novel({
		title = "---",
	})
	buffer[bufferSize + 2] = Novel({
		title = title,
	})
	buffer[bufferSize + 3] = Novel({
		title = "---",
	})
end

-- Listings
local listings = {
	Listing("Only", true, function(filters)
		local listingIndex = tonumber(filters[LISTING_SELECT]) or 0
		local genreIndex = tonumber(filters[GENRE_SELECT]) or 0
		local currentPage = tonumber(filters[PAGE]) or 1

		if genreIndex == 0 then
			if listingIndex == 0 then
				return parseBrowse("https://freewebnovel.com/sort/latest-novel/" .. currentPage)
			elseif listingIndex == 1 then
				return parseBrowse("https://freewebnovel.com/sort/latest-release/" .. currentPage)
			elseif listingIndex == 2 then
				local buffer = {}
				local bufferSize = 0

				local allVisit = parseBrowse("https://freewebnovel.com/sort/most-popular/")
				local dailyVisit = parseBrowse("https://freewebnovel.com/sort/most-popular/dayvisit")
				local weeklyVisit = parseBrowse("https://freewebnovel.com/sort/most-popular/weekvisit")
				local monthlyVisit = parseBrowse("https://freewebnovel.com/sort/most-popular/monthvisit")

				generatePlaceholder(buffer, "Most Visit")
				bufferSize = #buffer
				for i = 1, #allVisit do
					buffer[bufferSize + i] = allVisit[i]
				end
				generatePlaceholder(buffer, "Daily Visit")
				bufferSize = #buffer
				for i = 1, #dailyVisit do
					buffer[bufferSize + i] = dailyVisit[i]
				end
				generatePlaceholder(buffer, "Weekly Visit")
				bufferSize = #buffer
				for i = 1, #weeklyVisit do
					buffer[bufferSize + i] = weeklyVisit[i]
				end
				generatePlaceholder(buffer, "Monthly Visit")
				bufferSize = #buffer
				for i = 1, #monthlyVisit do
					buffer[bufferSize + i] = monthlyVisit[i]
				end

				return buffer
			else
				return parseBrowse("https://freewebnovel.com/sort/completed-novel/" .. currentPage)
			end
		end

		return parseBrowse("https://freewebnovel.com/genre/" .. GENRE_SELECT[genreIndex + 1] .. "/" .. currentPage)
	end),
}

local filterModel = {
	DropdownFilter(LISTING_SELECT, "Listing", LISTING_LIST),
	DropdownFilter(GENRE_SELECT, "Genre", GENRE_LIST),
	DropdownFilter(SEARCH_MODE_SELECT, "Search Mode", SEARCH_MODE_LIST),
}

local finalTable = {
	id = 777888888,
	name = "FreeWebNovel",
	baseURL = BASE_URL,
	imageURL = "https://sylixe.github.io/secret/icons/freewebnovel.png",

	hasSearch = true,
	hasCloudFlare = true,
	isSearchIncrementing = false,

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
