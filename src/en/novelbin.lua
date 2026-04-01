-- {"id":778888888,"ver":"1.0.1","libVer":"1.0.0","author":"Sylixe"}

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

local GENRE_URL_LIST = {
	"none",
	"action",
	"adult",
	"adventure",
	"anime-&-comics",
	"comedy",
	"drama",
	"eastern",
	"ecchi",
	"fan-fiction",
	"fantasy",
	"game",
	"gender-bender",
	"harem",
	"historical",
	"horror",
	"isekai",
	"josei",
	"lgbt+",
	"litrpg",
	"magic",
	"magical-realism",
	"martial-arts",
	"mature",
	"mecha",
	"military",
	"modern-life",
	"mystery",
	"other",
	"psychological",
	"reincarnation",
	"romance",
	"school-life",
	"sci-fi",
	"seinen",
	"shoujo",
	"shoujo-ai",
	"shounen",
	"shounen-ai",
	"slice-of-life",
	"smut",
	"sports",
	"supernatural",
	"system",
	"thriller",
	"tragedy",
	"urban",
	"video-games",
	"war",
	"wuxia",
	"xianxia",
	"xuanhuan",
	"yaoi",
	"yuri",
}

local STATUS_LIST = {
	"All",
	"Completed",
}

local SEARCH_MODE_LIST = {
	"Title",
	"Tag",
	"Author",
}

local STATUS_PICKER = {
	Ongoing = NovelStatus.PUBLISHING,
	Completed = NovelStatus.COMPLETED,
}

local QUERY = 0
local PAGE = 1
local GENRE_SELECT = 2
local STATUS_SELECT = 3
local SEARCH_MODE_SELECT = 4

local BASE_URL = "https://novelbin.com"
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

local select, selectFirst, attr, text
local size, get

local function shrinkURL(longURL)
	return sub(longURL, 21)
end

local function expandURL(smallURL)
	return BASE_URL .. smallURL
end

-- Browse listings
local function parseBrowse(novelListURL, useSRC)
	local doc = GETDocument(novelListURL)

	if not select then
		selectFirst = doc.selectFirst
		select = doc.select
		attr = doc.attr
		text = doc.text
	end

	local titleAndLinkDocList = select(doc, ".novel-title > a")
	local novelChapterCountList = select(doc, ".text-info > div > a")
	local imageDocList = select(doc, ".cover")

	if not size then
		size = titleAndLinkDocList.size
		get = titleAndLinkDocList.get
	end

	local listSize = titleAndLinkDocList:size()

	local finalListArray = {}
	for i = 0, listSize - 1 do
		local novelInfo = get(titleAndLinkDocList, i)
		local novelCountInfo = get(novelChapterCountList, i)
		local imageInfo = get(imageDocList, i)

		local novelTitle = attr(novelInfo, "title")
		local novelChapterCount = match(attr(novelCountInfo, "title"), "%d+") or "?"

		finalListArray[i + 1] = Novel({
			title = "(" .. novelChapterCount .. ") " .. novelTitle,
			imageURL = IMAGE_URL .. sub(attr(imageInfo, useSRC and "src" or "data-src"), 42), -- Change from Low res to High res
			link = shrinkURL(attr(novelInfo, "href")),
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
		query = upper(query)
	end

	return parseBrowse(searchURL .. query .. pageURL .. page, true)
end

-- Novel page
local function parseNovel(novelURL, loadChapters)
	local doc = GETDocument(expandURL(novelURL))

	local novelTitle = text(selectFirst(doc, ".title"))
	local novelImage = attr(selectFirst(doc, ".lazy"), "data-src")
	local novelDescription =
		sub(gsub(gsub(gsub(text(selectFirst(doc, ".desc-text")), "<br>", "\n"), "<p>", ""), "</p>", "\n"), 1, -2)
	local novelChapterCount = match(attr(selectFirst(doc, ".chapter-title"), "title"), "%d+") or "?"
	local novelStatusString = text(selectFirst(doc, ".text-primary"))
	local novelStatus = STATUS_PICKER[novelStatusString]
	local novelGenres = {}
	local novelTags = {}
	do
		local tagDocList = select(doc, ".tag-container > a")
		local listSize = size(tagDocList)

		for i = 0, listSize - 1 do
			novelGenres[i + 1] = text(get(tagDocList, i))
		end
	end

	local novelDescList = select(doc, ".info-meta > li")
	local descListSize = size(novelDescList)

	local novelAuthors
	for i = 0, descListSize - 1 do
		local decsDoc = get(novelDescList, i)
		local descTitle = selectFirst(decsDoc, "h3")

		if descTitle then
			local descTitleText = text(descTitle)
			if descTitleText == "Author:" then
				novelAuthors = { text(selectFirst(decsDoc, "a")) }
			elseif descTitleText == "Genre:" then
				local genreDocList = select(decsDoc, "a")
				local listSize = size(genreDocList)

				for j = 0, listSize - 1 do
					novelGenres[j + 1] = text(get(genreDocList, j))
				end
			end
		end
	end

	local novelFavoriteCount = tonumber(text(selectFirst(doc, ".small > em > strong:last-child > span")))
	local novelRating = text(selectFirst(doc, ".small > em > strong > span"))

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
		local chapterDocList = select(listingDoc, ".list-chapter > li > a")
		local listSize = size(chapterDocList)

		local chapterArray = {}
		for i = 0, listSize - 1 do
			local chapter = get(chapterDocList, i)
			local chapterLink = shrinkURL(attr(chapter, "href"))
			local chapterTitle = text(selectFirst(chapter, "span"))

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

	if not selectFirst then
		select = doc.select
		selectFirst = doc.selectFirst
	end

	local chap = selectFirst(doc, ".chr-c")
	local title = attr(selectFirst(doc, ".chr-title"), "title")
	select(doc, "div"):remove()
	chap:prepend("<h1>" .. title .. "</h1>")
	return pageOfElem(chap, true)
end

local filterModel = {
	DropdownFilter(GENRE_SELECT, "Genre", GENRE_LIST),
	DropdownFilter(STATUS_SELECT, "Status", STATUS_LIST),
	DropdownFilter(SEARCH_MODE_SELECT, "Search Mode", SEARCH_MODE_LIST),
}

local listings = {
	Listing("Latest Novels", true, function(filters)
		local genreIndex = tonumber(filters[GENRE_SELECT]) or 0
		local statusIndex = tonumber(filters[STATUS_SELECT]) or 0
		local currentPage = tonumber(filters[PAGE]) or 1

		if genreIndex == 0 then
			if statusIndex ~= nil and statusIndex ~= 0 then
				return parseBrowse("https://novelbin.com/sort/latest/completed?page=" .. currentPage)
			else
				return parseBrowse("https://novelbin.com/sort/latest?page=" .. currentPage)
			end
		end

		return parseBrowse(
			"https://novelbin.com/genre/"
				.. GENRE_URL_LIST[genreIndex + 1]
				.. (statusIndex == 1 and "/completed?page=" or "?page=")
				.. currentPage
		)
	end),
	Listing("Trending Novels", true, function(filters)
		local genreIndex = tonumber(filters[GENRE_SELECT]) or 0
		local statusIndex = tonumber(filters[STATUS_SELECT]) or 0
		local currentPage = tonumber(filters[PAGE]) or 1

		if genreIndex == 0 then
			if statusIndex ~= nil and statusIndex ~= 0 then
				return parseBrowse("https://novelbin.com/sort/top-hot-novel/completed?page=" .. currentPage)
			else
				return parseBrowse("https://novelbin.com/sort/top-hot-novel?page=" .. currentPage)
			end
		end

		return parseBrowse(
			"https://novelbin.com/genre/"
				.. GENRE_URL_LIST[genreIndex + 1]
				.. (statusIndex == 1 and "/completed?page=" or "?page=")
				.. currentPage
		)
	end),
	Listing("Popular Novels", true, function(filters)
		local genreIndex = tonumber(filters[GENRE_SELECT]) or 0
		local statusIndex = tonumber(filters[STATUS_SELECT]) or 0
		local currentPage = tonumber(filters[PAGE]) or 1

		if genreIndex == 0 then
			if statusIndex ~= nil and statusIndex ~= 0 then
				return parseBrowse("https://novelbin.com/sort/top-view-novel/completed?page=" .. currentPage)
			else
				return parseBrowse("https://novelbin.com/sort/top-view-novel?page=" .. currentPage)
			end
		end

		return parseBrowse(
			"https://novelbin.com/genre/"
				.. GENRE_URL_LIST[genreIndex + 1]
				.. (statusIndex == 1 and "/completed?page=" or "?page=")
				.. currentPage
		)
	end),
}

local finalTable = {
	id = 778888888,
	name = "NovelBin",
	baseURL = BASE_URL,
	imageURL = "https://sylixe.github.io/secret/icons/novelbin.png",

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
