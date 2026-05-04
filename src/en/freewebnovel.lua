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
	Ongoing = NovelStatus.PUBLISHING,
	Completed = NovelStatus.COMPLETED,
}

local QUERY = 0
local PAGE = 1
local LISTING_SELECT = 2
local GENRE_SELECT = 3

local BASE_URL = "https://freewebnovel.com"
local IMAGE_URL = "https://images.novelbin.com/novel/"
local TITLE_SEARCH_URL = "https://novelbin.com/search?keyword="
local AUTHOR_SEARCH_URL = "https://novelbin.com/a/"
local TAG_SEARCH_URL = "https://novelbin.com/tag/"

local gsub = string.gsub
local match = string.match
local sub = string.sub
local upper = string.upper
local tonumber = tonumber

local pageOfElem = pageOfElem

local GETDocument = GETDocument

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

	local titleAndLinkDocList = doc:select(".tit > a:not(.con)")
	local novelChapterCountDocList = doc:select(".chapter > .s1")
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
			imageURL = expandURL(imageDoc:attr("data-src")),
			link = titleDoc:attr("href"),
		})
	end

	return finalListArray
end

-- Search listings
local function search(filters)
	local searchMode = tonumber(filters[SEARCH_MODE_SELECT]) or 0
	local query = tostring(filters[QUERY])
	local page = tonumber(filters[PAGE]) or 1

	if query == "" then
		return {}
	end

	local pageURL = searchMode == 0 and "&page=" or "?page="
	local searchURL
	if searchMode == 0 then
		searchURL = TITLE_SEARCH_URL
	elseif searchMode == 1 then
		searchURL = TAG_SEARCH_URL
	else
		searchURL = AUTHOR_SEARCH_URL
	end

	if searchMode == 1 then
		return parseBrowse(searchURL .. upper(query) .. pageURL .. page, false)
	else
		return parseBrowse(searchURL .. query .. pageURL .. page, true)
	end
end

-- Novel page
local function parseNovel(novelURL, loadChapters)
	local doc = GETDocument(expandURL(novelURL))

	local novelTitle = doc:selectFirst(".title"):text()
	local novelImage = doc:selectFirst(".lazy"):attr("data-src")
	local novelDescription =
		sub(gsub(gsub(gsub(doc:selectFirst(".desc-text"):text(), "<br>", "\n"), "<p>", ""), "</p>", "\n"), 1, -2)
	local novelChapterCount = match(doc:selectFirst(".chapter-title"):attr("title"), "%d+") or "?"
	local novelStatusString = doc:selectFirst(".text-primary"):text()
	local novelStatus = STATUS_PICKER[novelStatusString]
	local novelGenres = {}
	local novelTags = {}
	do
		local tagDocList = doc:select(".tag-container > a")
		local listSize = tagDocList:size()

		for i = 0, listSize - 1 do
			novelGenres[i + 1] = tagDocList:get(i):text()
		end
	end

	local novelDescList = doc:select(".info-meta > li")
	local descListSize = novelDescList:size()

	local novelAuthors
	for i = 0, descListSize - 1 do
		local decsDoc = novelDescList:get(i)
		local descTitle = decsDoc:selectFirst("h3")

		if descTitle then
			local descTitleText = descTitle:text()
			if descTitleText == "Author:" then
				novelAuthors = { decsDoc:selectFirst("a"):text() }
			elseif descTitleText == "Genre:" then
				local genreDocList = decsDoc:select("a")
				local listSize = genreDocList:size()

				for j = 0, listSize - 1 do
					novelGenres[j + 1] = genreDocList:get(j):text()
				end
			end
		end
	end

	local novelFavoriteCount = tonumber(doc:selectFirst(".small > em > strong:last-child > span"):text())
	local novelRating = doc:selectFirst(".small > em > strong > span"):text()

	local finalNovelTitle
	if novelStatusString == "Ongoing" then
		finalNovelTitle = "(" .. novelChapterCount .. ") " .. novelTitle
	else
		finalNovelTitle = "[" .. novelChapterCount .. "] " .. novelTitle
	end

	local finalNovelDescription = "Rating: "
		.. novelRating
		.. "/10 from "
		.. novelFavoriteCount
		.. " ratings\n\n"
		.. novelDescription

	local novelData = {
		title = finalNovelTitle,
		imageURL = novelImage,
		description = finalNovelDescription,
		status = novelStatus,
		tags = novelTags,
		genres = novelGenres,
		authors = novelAuthors,
	}

	if loadChapters then
		local listingDoc = GETDocument("https://novelbin.com/ajax/chapter-archive?novelId=" .. sub(novelURL, 4))
		local chapterDocList = listingDoc:select(".list-chapter > li > a")
		local listSize = chapterDocList:size()

		local chapterArray = {}
		for i = 0, listSize - 1 do
			local chapter = chapterDocList:get(i)
			local chapterLink = shrinkURL(chapter:attr("href"))
			local chapterTitle = chapter:selectFirst("span"):text()

			chapterArray[i + 1] = NovelChapter({
				order = i + 1,
				title = chapterTitle,
				link = chapterLink,
			})
		end

		novelData.chapters = chapterArray
	end

	return NovelInfo(novelData)
end

-- Reader page
local function getPassage(chapterURL)
	local doc = GETDocument(expandURL(chapterURL))

	local chap = doc:selectFirst(".chr-c")
	local title = doc:selectFirst(".chr-text"):text()
	local hasExtraTitle = chap:selectFirst("h4")
	if hasExtraTitle ~= nil then
		chap:child(0):remove()
	end

	chap:select("div"):remove()
	chap:prepend("<h1>" .. title .. "</h1>")

	return pageOfElem(chap, true)
end

local filterModel = {
	DropdownFilter(LISTING_SELECT, "Listing", LISTING_LIST),
	DropdownFilter(GENRE_SELECT, "Genre", GENRE_LIST),
}

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

local finalTable = {
	id = 777888888,
	name = "FreeWebNovel",
	baseURL = BASE_URL,
	imageURL = "https://sylixe.github.io/secret/icons/freewebnovel.png",

	hasSearch = false,
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
