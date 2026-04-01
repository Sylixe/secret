-- {"id":778888888,"ver":"1.0.1","libVer":"1.0.0","author":"Sylixe"}

local GENRE_LIST = {
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
local SEARCH_REQUEST_URL = "https://www.wuxiabox.com/e/search/index.php"

local gsub = string.gsub
local match = string.match
local sub = string.sub
local find = string.find
local tonumber = tonumber

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

	local titleAndLinkDocList = select(doc, ".novel-title > a")
	local novelChapterCountList = select(doc, ".text-info > div > a")
	local imageDocList = select(doc, ".cover")

	if not size then
		size = titleAndLinkDocList.size
		get = titleAndLinkDocList.get
	end

	local listSize = size(titleAndLinkDocList)

	local finalListArray = {}
	for i = 0, listSize - 1 do
		local novelInfo = get(titleAndLinkDocList, i)
		local novelCountInfo = get(novelChapterCountList, i)
		local imageInfo = get(imageDocList, i)

		local novelTitle = attr(novelInfo, "title")
		local novelChapterCount = match(attr(novelCountInfo, "title"), "%d+") or "?"

		finalListArray[i + 1] = Novel({
			title = "(" .. novelChapterCount .. ") " .. novelTitle,
			imageURL = IMAGE_URL .. sub(attr(imageInfo, "data-src"), 42), -- Change from Low res to High res
			link = shrinkURL(attr(novelInfo, "href")),
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
		local selectedURL = selectFirst(doc, ".pagination > a:nth-child(2)")

		if not selectedURL then
			return {}
		end

		local searchLink = attr(selectedURL, "href")

		searchId = sub(searchLink, 44)
		searchMap[query] = searchId
	end

	return parseBrowse(expandURL("/e/search/result/index.php?page=" .. (page - 1) .. "&searchid=" .. searchId))
end

-- Helper
local function genreOrTagSelector(doc, section, finalTable)
	local genreList = select(doc, ".categories > ul:nth-child(" .. section .. ") > li > a")
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

	local novelTitle = text(selectFirst(doc, ".title"))
	local novelImage = attr(selectFirst(doc, ".lazy"), "data-src")
	local novelDescription =
		sub(gsub(gsub(gsub(text(selectFirst(doc, ".desc-text")), "<br>", "\n"), "<p>", ""), "</p>", "\n"), 1, -2)
	local novelChapterCount = match(attr(selectFirst(doc, ".chapter-title"), "title"), "%d+") or "?"
	local novelStatusString = text(selectFirst(doc, ".text-primary"))
	local novelStatus = STATUS_PICKER[novelStatusString]
	local novelArtists, novelAuthors, novelAltTitle
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
	for i = 0, descListSize - 1 do
		local decsDoc = get(novelDescList, i)
		local descTitle = selectFirst(decsDoc, "h3")

		if descTitle then
			local descTitleText = text(descTitle)
			if descTitleText == "Author:" then
				novelArtists = { text(selectFirst(decsDoc, "a")) }
			elseif descTitleText == "Genre:" then
				local genreDocList = select(decsDoc, "a")
				local listSize = size(genreDocList)

				for j = 0, listSize - 1 do
					novelGenres[j + 1] = text(get(genreDocList, j))
				end
			elseif descTitleText == "Publishers:" then
				novelAuthors = { sub(text(decsDoc), 53, -29) }
			elseif descTitleText == "Alternative names: " then
				novelAltTitle = { sub(text(decsDoc), 61, -29) }
			end
		end
	end

	local novelCommentCount = tonumber(text(selectFirst(doc, ".text-center > span")))
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
		alternativeTitles = novelAltTitle,
		imageURL = novelImage,
		description = finalNovelDescription,
		status = novelStatus,
		tags = novelTags,
		genres = novelGenres,
		authors = novelAuthors,
		artists = novelArtists,
		commentCount = novelCommentCount,
		favoriteCount = novelFavoriteCount,
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
	chap:prepend("<style>div { display: none !important; }</style>")
	chap:prepend("<h1>" .. title .. "</h1>")
	return pageOfElem(chap)
end

local filterModel = {
	DropdownFilter(GENRE_SELECT, "Genre", GENRE_LIST),
	DropdownFilter(STATUS_SELECT, "Status", STATUS_LIST),
	DropdownFilter(SEARCH_MODE_SELECT, "Search Mode", SEARCH_MODE_LIST),
}

local listings = {
	Listing("Latest Novels", true, function(filters)
		local genreIndex = filters[GENRE_SELECT]
		local statusIndex = filters[STATUS_SELECT]
		local currentPage = filters[PAGE]

		if genreIndex == nil then
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
		local genreIndex = filters[GENRE_SELECT]
		local statusIndex = filters[STATUS_SELECT]
		local currentPage = filters[PAGE]

		if genreIndex == nil then
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
		local genreIndex = filters[GENRE_SELECT]
		local statusIndex = filters[STATUS_SELECT]
		local currentPage = filters[PAGE]

		if genreIndex == nil then
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
