# Main Functions
loadSettings = ->
  channels_cookie = $.jStorage.get("user_channels")
  auto_cookie = $.jStorage.get("auto")
  sfw_cookie = $.jStorage.get("sfw")
  theme_cookie = $.jStorage.get("theme")
  shuffle_cookie = $.jStorage.get("shuffle")
  if auto_cookie isnt null and auto_cookie isnt Globals.auto
    Globals.auto = (if (auto_cookie is "true") then true else false)
    $("#auto").attr "checked", Globals.auto
  if shuffle_cookie isnt null and shuffle_cookie isnt Globals.shuffle
    Globals.shuffle = (if (shuffle_cookie is "true") then true else false)
    $("#shuffle").attr "checked", Globals.shuffle
  if sfw_cookie isnt null and sfw_cookie isnt Globals.sfw
    Globals.sfw = (if (sfw_cookie is "true") then true else false)
    $("#sfw").attr "checked", Globals.sfw
  Globals.theme = theme_cookie  if theme_cookie isnt null and theme_cookie isnt Globals.theme
  if channels_cookie isnt null and channels_cookie isnt Globals.user_channels
    Globals.user_channels = channels_cookie
    for x of Globals.user_channels
      Globals.channels.push Globals.user_channels[x]
loadTheme = (id) ->
  $("#theme").attr "href", "css/theme_" + id + ".css"
  $.jStorage.set "theme", id
displayChannels = ->
  $channel_list = $("#channel-list")
  $list = $("<ul></ul>")
  $channel_list.html $list
  for x of Globals.channels
    displayChannel x
displayChannel = (chan) ->
  title = undefined
  display_title = undefined
  class_str = ""
  remove_str = ""
  title = Globals.channels[chan].feed.split("/")
  title = "/" + title[1] + "/" + title[2]
  display_title = (if Globals.channels[chan].channel.length > 8 then Globals.channels[chan].channel.replace(/[aeiou]/g, "").substr(0, 7) else Globals.channels[chan].channel)
  if isUserChan(Globals.channels[chan].channel)
    class_str = "class=\"user-chan\""
    remove_str = "<a id=\"remove-" + chan + "\" class=\"remove-chan\">-</a>"
  $("#channel-list>ul").append "<li id=\"channel-" + chan + "\" title=\"" + title + "\" " + class_str + ">" + display_title + remove_str + "</li>"
  $("#channel-" + chan).bind "click",
    channel: Globals.channels[chan].channel
    feed: Globals.channels[chan].feed
  , (event) ->
    parts = event.data.feed.split("/")
    window.location.hash = "/" + parts[1] + "/" + parts[2] + "/"

  $("#remove-" + chan).bind "click",
    channel: chan
  , (event) ->
    removeChan event.data.channel

loadChannel = (channel, video_id) ->
  last_req = Globals.cur_chan_req
  this_chan = getChan(channel)
  $video_embed = $("#video-embed")
  $video_title = $("#video-title")
  title = undefined
  last_req.abort()  if last_req isnt null
  #reset
  Globals.shuffled = []
  Globals.cur_chan = this_chan
  $("#video-list").stop(true, true).animate
    height: 0
    padding: 0
  , 500, ->
    $(this).empty().hide()

  $("#prev-button,#next-button").css
    visibility: "hidden"
    display: "none"

  $("#vote-button").empty()
  $("#video-source").empty()
  title = Globals.channels[this_chan].feed.split("/")
  title = "/" + title[1] + "/" + title[2]
  $video_title.html "Loading " + title + " ..."
  $video_embed.addClass "loading"
  $video_embed.empty()
  $("#channel-list>ul>li").removeClass "chan-selected"
  $("#channel-" + this_chan).addClass "chan-selected"
  if Globals.videos[this_chan] is `undefined`
    feed = getFeedURI(channel)
    Globals.cur_chan_req = $.ajax(
      url: "http://www.reddit.com" + feed
      dataType: "jsonp"
      jsonp: "jsonp"
      success: (data) ->
        Globals.videos[this_chan] = {}
        Globals.videos[this_chan].video = [] #clear out stored videos
        for x of data.data.children
          if isVideo(data.data.children[x].data.domain) and (data.data.children[x].data.score > 1)
            if isEmpty(data.data.children[x].data.media_embed) or data.data.children[x].data.domain is "youtube.com" or data.data.children[x].data.domain is "youtu.be"
              created = createEmbed(data.data.children[x].data.url, data.data.children[x].data.domain)
              if created isnt false
                data.data.children[x].data.media_embed.content = created.embed
                data.data.children[x].data.media = {}
                data.data.children[x].data.media.oembed = {}
                data.data.children[x].data.media.oembed.thumbnail_url = created.thumbnail
            Globals.videos[this_chan].video.push data.data.children[x].data  if data.data.children[x].data.media_embed.content
        
        #remove duplicates
        Globals.videos[this_chan].video = filterVideoDupes(Globals.videos[this_chan].video)
        if Globals.videos[this_chan].video.length > 0
          if video_id isnt null
            loadVideoById video_id
          else
            loadVideoList this_chan
            Globals.cur_video = 0
            loadVideo "first"
          $video_embed.removeClass "loading"
        else
          $video_embed.removeClass "loading"
          alert "No videos found in " + Globals.channels[this_chan].channel

      error: (jXHR, textStatus, errorThrown) ->
        alert "Could not load feed. Is reddit down?"  if textStatus isnt "abort"
    )
  else
    if Globals.videos[this_chan].video.length > 0
      if video_id isnt null
        loadVideoById video_id
      else
        loadVideoList this_chan
        Globals.cur_video = 0
        loadVideo "first"
    else
      alert "No videos loaded for " + Globals.channels[this_chan].feed.slice(0, -5)
loadVideoList = (chan) ->
  this_chan = chan
  $list = $("<span></span>")
  for i of Globals.videos[this_chan].video
    this_video = Globals.videos[this_chan].video[i]
    unless this_video.title_unesc
      this_video.title_unesc = $.unescapifyHTML(this_video.title)
      this_video.title_quot = String(this_video.title_unesc).replace(/\"/g, "&quot;")
    $thumbnail = $("<img id=\"video-list-thumb-" + i + "\"" + " rel=\"" + i + "\"" + " title=\"" + this_video.title_quot + "\"/>")
    
    # make nsfw thumbnails easily findable
    $thumbnail.addClass "nsfw_thumb"  if this_video.over_18
    $thumbnail.attr("src", "img/noimage.png").attr("data-original", getThumbnailUrl(this_chan, i)).click ->
      loadVideo Number($(this).attr("rel"))

    $list.append $thumbnail
  $("#video-list").stop(true, true).html($list).show().animate
    height: "88px"
    padding: "5px"
  , 1000, ->
    $("img").lazyload
      effect: "fadeIn"
      container: $("#video-list")


loadVideo = (video) ->
  this_chan = Globals.cur_chan
  this_video = Globals.cur_video
  selected_video = this_video
  videos_size = Object.size(Globals.videos[this_chan].video) - 1
  if Globals.shuffle
    shuffleChan this_chan  if Globals.shuffled.length is 0
    
    #get normal key if shuffled already
    selected_video = Globals.shuffled.indexOf(selected_video)
  if video is "next" and selected_video <= videos_size
    selected_video++
    selected_video = 0  if selected_video > videos_size
    selected_video++  while sfwCheck(getVideoKey(selected_video), this_chan) and selected_video < videos_size
    selected_video = this_video  if sfwCheck(getVideoKey(selected_video), this_chan)
  else if selected_video >= 0 and video is "prev"
    selected_video--
    selected_video = videos_size  if selected_video < 0
    selected_video--  while sfwCheck(getVideoKey(selected_video), this_chan) and selected_video > 0
    selected_video = this_video  if sfwCheck(getVideoKey(selected_video), this_chan)
  else if video is "first"
    selected_video = 0
    selected_video++  while sfwCheck(getVideoKey(selected_video), this_chan) and selected_video < videos_size  if sfwCheck(getVideoKey(selected_video), this_chan)
  selected_video = getVideoKey(selected_video)
  #must be a number NOT A STRING - allows direct load of video # in video array
  selected_video = video  if typeof (video) is "number"
  
  #exit if trying to load over_18 content without confirmed over 18
  return false  if sfwCheck(selected_video, this_chan)
  if selected_video isnt this_video or video is "first" or video is 0
    Globals.cur_video = selected_video
    
    # scroll to thumbnail in video list and highlight it
    $("#video-list .focus").removeClass "focus"
    $("#video-list-thumb-" + selected_video).addClass "focus"
    $("#video-list").stop(true, true).scrollTo ".focus",
      duration: 1000
      offset: -280

    
    # enable/disable nav-buttons at end/beginning of playlist
    $prevbutton = $("#prev-button")
    $nextbutton = $("#next-button")
    if selected_video <= 0
      $prevbutton.stop(true, true).fadeOut "slow", ->
        $(this).css
          visibility: "hidden"
          display: "inline"


    else $prevbutton.hide().css(visibility: "visible").stop(true, true).fadeIn "slow"  if $prevbutton.css("visibility") is "hidden"
    if Globals.cur_video >= videos_size
      $nextbutton.stop(true, true).fadeOut "slow", ->
        $(this).css
          visibility: "hidden"
          display: "inline"


    else $nextbutton.hide().css(visibility: "visible").stop(true, true).fadeIn "slow"  if $nextbutton.css("visibility") is "hidden"
    
    #set location hash
    parts = undefined
    hash = document.location.hash
    unless hash
      feed = Globals.channels[this_chan].feed
      parts = feed.split("/")
      hash = "/" + parts[1] + "/" + parts[2] + "/" + Globals.videos[this_chan].video[selected_video].id
    else
      anchor = hash.substring(1)
      parts = anchor.split("/") # #/r/videos/id
      hash = "/" + parts[1] + "/" + parts[2] + "/" + Globals.videos[this_chan].video[selected_video].id
    Globals.current_anchor = "#" + hash
    window.location.hash = hash
    gaHashTrack()
    $video_embed = $("#video-embed")
    $video_embed.empty()
    $video_embed.addClass "loading"
    embed = $.unescapifyHTML(Globals.videos[this_chan].video[selected_video].media_embed.content)
    embed = prepEmbed(embed, Globals.videos[this_chan].video[selected_video].domain)
    embed = prepEmbed(embed, "size")
    redditlink = "http://reddit.com" + $.unescapifyHTML(Globals.videos[this_chan].video[selected_video].permalink)
    $("#video-title").html "<a href=\"" + redditlink + "\" target=\"_blank\"" + " title=\"" + Globals.videos[this_chan].video[selected_video].title_quot + "\">" + Globals.videos[this_chan].video[selected_video].title_unesc + "</a>"
    $video_embed.html embed
    $video_embed.removeClass "loading"
    addListeners Globals.videos[this_chan].video[selected_video].domain
    reddit_string = redditButton("t3_" + Globals.videos[this_chan].video[selected_video].id)
    $vote_button = $("#vote-button")
    $vote_button.stop(true, true).fadeOut "slow", ->
      $vote_button.html(reddit_string).fadeTo "slow", 1

    video_source_text = "Source: " + "<a href=\"" + Globals.videos[this_chan].video[selected_video].url + "\" target=\"_blank\">" + Globals.videos[this_chan].video[selected_video].domain + "</a>"
    $video_source = $("#video-source")
    $video_source.stop(true, true).fadeOut "slow", ->
      $video_source.html(video_source_text).fadeIn "slow"

    resizePlayer()
    fillScreen()
getVideoKey = (key) ->
  if Globals.shuffle and Globals.shuffled.length is Globals.videos[Globals.cur_chan].video.length
    Globals.shuffled[key]
  else
    key
loadVideoById = (video_id) ->
  this_chan = Globals.cur_chan #returns number typed
  video = findVideoById(video_id, this_chan)
  if video isnt false
    loadVideoList this_chan
    loadVideo Number(video)
  else
    
    #ajax request
    last_req = Globals.cur_vid_req
    last_req.abort()  if last_req isnt null
    Globals.cur_vid_req = $.ajax(
      url: "http://www.reddit.com/by_id/t3_" + video_id + ".json"
      dataType: "jsonp"
      jsonp: "jsonp"
      success: (data) ->
        Globals.videos[this_chan].video.splice 0, 0, data.data.children[0].data  if not isEmpty(data.data.children[0].data.media_embed) and isVideo(data.data.children[0].data.media.type)
        loadVideoList this_chan
        loadVideo "first"

      error: (jXHR, textStatus, errorThrown) ->
        alert "Could not load data. Is reddit down?"  if textStatus isnt "abort"
    )
loadPromo = (type, id, desc) ->
  consoleLog "loading promo"
  Globals.cur_chan_req.abort()  if Globals.cur_chan_req
  created = undefined
  url = undefined
  embed = undefined
  domain = type + ".com"
  hash = "/promo/" + type + "/" + id + "/" + desc
  Globals.current_anchor = "#" + hash
  window.location.hash = hash
  gaHashTrack()
  switch type
    when "youtube"
      url = "http://www.youtube.com/watch?v=" + id
    when "vimeo"
      url = "http://vimeo.com/" + id
    else
      consoleLog "unsupported promo type"
  created = createEmbed(url, domain)
  if created isnt false
    embed = prepEmbed($.unescapifyHTML(created.embed), domain)
    embed = prepEmbed(embed, "size")
    $video_embed = $("#video-embed")
    $video_embed.empty()
    $video_embed.addClass "loading"
    $("#video-title").text unescape(desc)
    $video_embed.html embed
    $video_embed.removeClass "loading"
    addListeners domain
    video_source_text = "Source: " + "<a href=\"" + url + "\" target=\"_blank\">" + domain + "</a>"
    $video_source = $("#video-source")
    $video_source.stop(true, true).fadeOut "slow", ->
      $video_source.html(video_source_text).fadeIn "slow"

  else
    consoleLog "unable to create promo embed"
isVideo = (video_domain) ->
  Globals.domains.indexOf(video_domain) isnt -1

#http://dreaminginjavascript.wordpress.com/2008/08/22/eliminating-duplicates/
filterVideoDupes = (arr) ->
  i = undefined
  out = []
  obj = {}
  original_length = arr.length
  
  #work from last video to first video (so hottest dupe is left standing)
  #first pass on media embed
  i = arr.length - 1
  while i >= 0
    delete obj[arr[i].media_embed.content]  if typeof obj[arr[i].media_embed.content] isnt "undefined"
    obj[arr[i].media_embed.content] = arr[i]
    i--
  for i of obj
    out.push obj[i]
  arr = out.reverse()
  out = []
  obj = {}
  
  #second pass on url
  i = arr.length - 1
  while i >= 0
    delete obj[arr[i].url]  if typeof obj[arr[i].url] isnt "undefined"
    obj[arr[i].url] = arr[i]
    i--
  for i of obj
    out.push obj[i]
  out.reverse()
findVideoById = (id, chan) ->
  for x of Globals.videos[chan].video
    return Number(x)  if Globals.videos[chan].video[x].id is id #if found return array pos
  false #not found
sfwCheck = (video, chan) ->
  Globals.sfw and Globals.videos[chan].video[video].over_18
showHideNsfwThumbs = (sfw, this_chan) ->
  $(".nsfw_thumb").each ->
    $(this).attr "src", getThumbnailUrl(this_chan, Number($(this).attr("rel")))

getThumbnailUrl = (chan, video_id) ->
  if sfwCheck(video_id, chan)
    "img/nsfw.png"
  else if Globals.videos[chan].video[video_id].media.oembed
    (if Globals.videos[chan].video[video_id].media.oembed.thumbnail_url isnt `undefined` then Globals.videos[chan].video[video_id].media.oembed.thumbnail_url else "img/noimage.png")
  else
    "img/noimage.png"
chgChan = (up_down) ->
  old_chan = Globals.cur_chan
  this_chan = old_chan
  if up_down is "up" and this_chan > 0
    this_chan--
    this_chan--  while Globals.channels[this_chan].channel is "" and this_chan > 0
  else if up_down is "up"
    this_chan = Globals.channels.length - 1
    this_chan--  while Globals.channels[this_chan].channel is "" and this_chan > 0
  else if up_down isnt "up" and this_chan < Globals.channels.length - 1
    this_chan++
    this_chan++  while Globals.channels[this_chan].channel is ""
  else if up_down isnt "up"
    this_chan = 0
    this_chan++  while Globals.channels[this_chan].channel is ""
  if this_chan isnt old_chan and Globals.channels[this_chan].channel isnt ""
    parts = Globals.channels[this_chan].feed.split("/")
    window.location.hash = "/" + parts[1] + "/" + parts[2] + "/"
  else Globals.cur_chan = this_chan  if this_chan isnt old_chan
getFeedURI = (channel) ->
  for x of Globals.channels
    return formatFeedURI(Globals.channels[x])  if Globals.channels[x].channel is channel
formatFeedURI = (channel_obj) ->
  sorting = Globals.sorting.split(":")
  sortType = ""
  sortOption = ""
  uri = undefined
  if sorting.length is 2
    sortType = sorting[0] + "/"
    sortOption = "&t=" + sorting[1]
  if channel_obj.type is "search" and sorting.length is 1
    uri = channel_obj.feed + Globals.search_str + "&limit=100"
  else
    uri = channel_obj.feed + sortType + ".json?limit=100" + sortOption
  console.log uri
  uri
getChanName = (feed) ->
  for x of Globals.channels
    return Globals.channels[x].channel  if Globals.channels[x].feed.indexOf(feed) isnt -1
  false
getChan = (channel) ->
  for x of Globals.channels
    return x  if Globals.channels[x].channel is channel or Globals.channels[x].feed is channel
  false
getUserChan = (channel) ->
  for x of Globals.channels
    return x  if Globals.user_channels[x].channel is channel or Globals.user_channels[x].feed is channel
  false
isUserChan = (channel) ->
  for x of Globals.user_channels
    return true  if Globals.user_channels[x].channel is channel
  false
createEmbed = (url, type) ->
  switch type
    when "youtube.com", "youtu.be"
      youtube.createEmbed url
    when "vimeo.com"
      vimeo.createEmbed url
    else
      false
prepEmbed = (embed, type) ->
  switch type
    when "youtube.com", "youtu.be"
      youtube.prepEmbed embed
    when "vimeo.com"
      vimeo.prepEmbed embed
    when "size"
      embed = embed.replace(/height\="(\d\w+)"/g, "height=\"480\"")
      embed = embed.replace(/width\="(\d\w+)"/g, "width=\"640\"")
      embed
    else
      embed
addListeners = (type) ->
  switch type
    when "vimeo.com"
      vimeo.addListeners()
fillScreen = ->
  $object = undefined
  $fill = undefined
  $filloverlay = undefined
  fill_screen_domains = ["youtube.com", "youtu.be"]
  if fill_screen_domains.indexOf(Globals.videos[Globals.cur_chan].video[Globals.cur_video].domain) isnt -1
    $object = $("#video-embed embed")
    $fill = $("#fill")
    # Bindings 
    $filloverlay = $("#fill-overlay")
    if $object.hasClass("fill-screen")
      $fill.attr "checked", false
      $object.removeClass "fill-screen"
      $filloverlay.css "display", "none"
    else if $fill.is(":checked")
      $fill.attr "checked", true
      $object.addClass "fill-screen"
      $filloverlay.css "display", "block"
resizePlayer = ->
  if typeof (Globals.cur_chan) is "undefined" or typeof (Globals.videos[Globals.cur_chan]) is "undefined"
    setTimeout resizePlayer, 100
    return
  consoleLog "window size changed: " + $(window).width() + "x" + $(window).height()
  sitename = Globals.videos[Globals.cur_chan].video[Globals.cur_video].domain
  if sitename is "youtube.com" or sitename is "youtu.be"
    player = $("#ytplayer")
  else if sitename is "vimeo.com"
    player = $("#vimeoplayer")
  else
    consoleLog "unsupported player: " + sitename
    return
  curr_player_width = player.width()
  curr_player_height = player.height()
  win_width = $(window).width()
  win_height = $(window).height()
  
  # consoleLog('content_min size: ' + (Globals.content_minwidth+curr_player_width) + 'x' + (Globals.content_minheight+curr_player_height));
  # consoleLog('vd_min size: ' + (Globals.vd_minwidth+curr_player_width) + 'x' + (Globals.vd_minheight+curr_player_height));
  if win_width < 853 + Globals.content_minwidth or win_height < 505 + Globals.content_minheight
    player_width = 640
    player_height = 385
  else if win_width < 1280 + Globals.content_minwidth or win_height < 745 + Globals.content_minheight
    player_width = 853
    player_height = 505
  else
    player_width = 1280
    player_height = 745
  return  if player_width is curr_player_width # nothing to do
  consoleLog "resizing player to " + player_width + "x" + player_height
  player.width player_width
  player.height player_height
  player_width = player.width() # player may not accept our request
  player_height = player.height()
  consoleLog "new player size: " + player_width + "x" + player_height
  $("#content").width player_width + Globals.content_minwidth
  $("#video-display").width player_width + Globals.vd_minwidth
  $("#video-display").height player_height + Globals.vd_minheight
togglePlay = ->
  switch Globals.videos[Globals.cur_chan].video[Globals.cur_video].domain
    when "youtube.com", "youtu.be"
      youtube.togglePlay()
    when "vimeo.com"
      vimeo.togglePlay()
addChannel = (subreddit) ->
  click = undefined
  unless subreddit
    subreddit = stripHTML($("#channel-name").val())
    click = true
  unless getChan(subreddit)
    feed = "/r/" + subreddit + "/"
    c_data =
      channel: subreddit
      feed: feed

    Globals.channels.push c_data
    Globals.user_channels.push c_data
    $.jStorage.set "user_channels", Globals.user_channels
    x = Globals.channels.length - 1
    displayChannel x
    $("#channel-" + x).click()  if click
  false
removeChan = (chan) -> #by index (integer)
  idx = getUserChan(Globals.channels[chan].channel)
  if idx
    chgChan "up"  if parseInt(chan) is parseInt(Globals.cur_chan)
    $("#channel-" + chan).remove()
    Globals.user_channels.splice idx, 1
    $.jStorage.set "user_channels", Globals.user_channels
    
    #free some memory bitches
    Globals.channels[chan] =
      channel: ""
      feed: ""

    Globals.videos[chan] = `undefined`
shuffleChan = (chan) -> #by index (integer
  # 
  #       does not shuffle actual video array
  #       but rather creates a global array of shuffled keys
  #    
  Globals.shuffled = [] # reset
  for x of Globals.videos[chan].video
    Globals.shuffled.push x
  Globals.shuffled = shuffleArray(Globals.shuffled)
  consoleLog "shuffling channel " + chan

# Anchor Checker 

#check fo anchor changes, if there are do stuff
checkAnchor = ->
  if Globals.current_anchor isnt document.location.hash
    consoleLog "anchor changed"
    Globals.current_anchor = document.location.hash
    if Globals.current_anchor
      
      # do nothing 
      anchor = Globals.current_anchor.substring(1)
      parts = anchor.split("/") # #/r/videos/id
      parts = $.map(parts, stripHTML)
      if parts[1] is "promo"
        loadPromo parts[2], parts[3], parts[4]
      else
        feed = "/" + parts[1] + "/" + parts[2] + "/"
        new_chan_name = getChanName(feed)
        unless new_chan_name
          addChannel parts[2]
          new_chan_name = getChanName(feed)
        new_chan_num = getChan(new_chan_name)
        if new_chan_name isnt `undefined` and new_chan_num isnt Globals.cur_chan
          if parts[3] is `undefined` or parts[3] is null or parts[3] is ""
            loadChannel new_chan_name, null
          else
            loadChannel new_chan_name, parts[3]
        else
          if Globals.videos[new_chan_num] isnt `undefined`
            loadVideoById parts[3]
          else
            loadChannel new_chan_name, parts[3]
  else
    false

# Reddit Functions 
redditButton = (id) ->
  reddit_string = "<iframe src=\"http://www.reddit.com/static/button/button1.html?width=120"
  reddit_string += "&id=" + id
  
  #reddit_string += '&css=' + encodeURIComponent(window.reddit_css);
  #reddit_string += '&bgcolor=' + encodeURIComponent(window.reddit_bgcolor);
  #reddit_string += '&bordercolor=' + encodeURIComponent(window.reddit_bordercolor);
  reddit_string += "&newwindow=" + encodeURIComponent("1")
  reddit_string += "\" height=\"22\" width=\"150\" scrolling='no' frameborder='0'></iframe>"
  reddit_string

# Utility Functions 

#safe console log
@consoleLog = (string) ->
  console.log string  if window.console

#http://stackoverflow.com/questions/962802/is-it-correct-to-use-javascript-array-sort-method-for-shuffling/962890#962890
shuffleArray = (array) ->
  tmp = undefined
  current = undefined
  top = array.length
  if top
    while --top
      current = Math.floor(Math.random() * (top + 1))
      tmp = array[current]
      array[current] = array[top]
      array[top] = tmp
  array
isEmpty = (obj) ->
  for prop of obj
    return false  if obj.hasOwnProperty(prop)
  true
stripHTML = (s) ->
  s.replace /[&<>"'\/]/g, ""

@Globals =
  # build uri for search type channels 
  search_str: (->
    one_day = 86400
    date = new Date()
    unixtime_ms = date.getTime()
    unixtime = parseInt(unixtime_ms / 1000)
    "search/.json?q=%28and+%28or+site%3A%27youtube.com%27+site%3A%27vimeo.com%27+site%3A%27youtu.be%27%29+timestamp%3A" + (unixtime - 5 * one_day) + "..%29&restrict_sr=on&sort=top&syntax=cloudsearch"
  )()
  # Channels Object
  channels: [
    channel: "All"
    type: "search"
    feed: "/r/all/"
  ,
    channel: "Videos"
    type: "normal"
    feed: "/r/videos/"
  ,
    channel: "Funny"
    type: "search"
    feed: "/r/funny/"
  ,
    channel: "Tech"
    type: "search"
    feed: "/r/technology/"
  ,
    channel: "Gaming"
    type: "normal"
    feed: "/r/gaming/"
  ,
    channel: "AWW"
    type: "search"
    feed: "/r/aww/"
  ,
    channel: "WTF"
    type: "search"
    feed: "/r/wtf/"
  ,
    channel: "Music"
    type: "normal"
    feed: "/r/music/"
  ,
    channel: "Listen"
    type: "normal"
    feed: "/r/listentothis/"
  ,
    channel: "TIL"
    type: "search"
    feed: "/r/todayilearned/"
  ,
    channel: "PBS"
    type: "domain"
    feed: "/domain/video.pbs.org/"
  ,
    channel: "TED"
    type: "domain"
    feed: "/domain/ted.com/"
  ,
    channel: "Politics"
    type: "search"
    feed: "/r/politics/"
  ,
    channel: "Atheism"
    type: "search"
    feed: "/r/atheism/"
  ,
    channel: "Sports"
    type: "normal"
    feed: "/r/sports/"
  ]
  # Video Domains
  domains: ["5min.com", "abcnews.go.com", "animal.discovery.com", "animoto.com", "atom.com", "bambuser.com", "bigthink.com", "blip.tv", "break.com", "cbsnews.com", "cnbc.com", "cnn.com", "colbertnation.com", "collegehumor.com", "comedycentral.com", "crackle.com", "dailymotion.com", "dsc.discovery.com", "discovery.com", "dotsub.com", "edition.cnn.com", "escapistmagazine.com", "espn.go.com", "fancast.com", "flickr.com", "fora.tv", "foxsports.com", "funnyordie.com", "gametrailers.com", "godtube.com", "howcast.com", "hulu.com", "justin.tv", "kinomap.com", "koldcast.tv", "liveleak.com", "livestream.com", "mediamatters.org", "metacafe.com", "money.cnn.com", "movies.yahoo.com", "msnbc.com", "nfb.ca", "nzonscreen.com", "overstream.net", "photobucket.com", "qik.com", "redux.com", "revision3.com", "revver.com", "schooltube.com", "screencast.com", "screenr.com", "sendables.jibjab.com", "spike.com", "teachertube.com", "techcrunch.tv", "ted.com", "thedailyshow.com", "theonion.com", "traileraddict.com", "trailerspy.com", "trutv.com", "twitvid.com", "ustream.com", "viddler.com", "video.google.com", "video.nationalgeographic.com", "video.pbs.org", "video.yahoo.com", "vids.myspace.com", "vimeo.com", "wordpress.tv", "worldstarhiphop.com", "xtranormal.com", "youtube.com", "youtu.be", "zapiks.com"]
  sorting: "hot"
  videos: []
  user_channels: []
  cur_video: 0
  cur_chan: 0
  cur_chan_req: null
  cur_vid_req: null
  current_anchor: null
  auto: true
  sfw: true
  shuffle: false
  shuffled: []
  theme: "light"

  # minimum width of #content w/o width of player
  # minimum height of #content w/o height of player
  # minimum width of #video-display w/o width of player
  # minimum height of #video-display w/o height of player
  content_minwidth: 130
  content_minheight: 320
  vd_minwidth: 30
  vd_minheight: 213

# MAIN (Document Ready)
$().ready ->
  loadSettings()
  loadTheme Globals.theme
  displayChannels()
  loadChannel "Videos", null
  $filloverlay = $("#fill-overlay")
  $fillnav = $("#fill-nav")
  $filloverlay.mouseenter ->
    $fillnav.slideDown "slow"

  $filloverlay.mouseleave ->
    $fillnav.slideUp "slow"

  $fillnav.click ->
    fillScreen()

  $("#css li a").click ->
    loadTheme $(this).attr("rel")
    false

  $("#auto").click ->
    Globals.auto = (if ($("#auto").is(":checked")) then true else false)
    $.jStorage.set "auto", Globals.auto

  $("#shuffle").click ->
    Globals.shuffle = (if ($("#shuffle").is(":checked")) then true else false)
    Globals.shuffled = []
    $.jStorage.set "shuffle", Globals.shuffle

  $("#sfw").click ->
    Globals.sfw = (if ($("#sfw").is(":checked")) then true else false)
    unless Globals.sfw
      unless confirm("Are you over 18?")
        $("#sfw").prop "checked", true
        Globals.sfw = true
    $.jStorage.set "sfw", Globals.sfw
    showHideNsfwThumbs Globals.sfw, Globals.cur_chan

  $("#fill").click ->
    fillScreen()

  $("#next-button").click ->
    loadVideo "next"

  $("#prev-button").click ->
    loadVideo "prev"

  $("#video-list").bind "mousewheel", (event, delta) ->
    @scrollLeft -= (delta * 30)

  $("#sorting").on "change", ->
    Globals.sorting = $("#sorting").val()
    Globals.videos = []
    loadChannel Globals.channels[Globals.cur_chan].channel, null

  $(document).keydown (e) ->
    unless $(e.target).is("form>*")
      keyCode = e.keyCode or e.which
      arrow =
        left: 37
        up: 38
        right: 39
        down: 40

      switch keyCode
        # h
        when arrow.left, 72
          loadVideo "prev"
        # k
        when arrow.up, 75
          chgChan "up"
        # l
        when arrow.right, 76
          loadVideo "next"
        # j
        when arrow.down, 74
          chgChan "down"
        when 32
          togglePlay()
        when 70
          $("#fill").attr "checked", true
          fillScreen()
        when 27
          fillScreen()  if $("#fill").is(":checked")
        when 67
          window.open $("#video-title>a").attr("href"), "_blank"
      false

  $(window).resize ->
    resizePlayer()

  # clear add sr on click
  $("#channel-name").click ->
    $(this).val ""

  # Anchor Checker
  if "onhashchange" of window
    # perform initial check if hotlinked
    checkAnchor()
    window.onhashchange = ->
      checkAnchor()
  else
    setInterval checkAnchor, 100

Object.size = (obj) ->
  size = 0
  key = undefined
  for key of obj
    size++  if obj.hasOwnProperty(key)
  size

# analytics
gaHashTrack = ->
  _gaq.push ["_trackPageview", location.pathname + location.hash]  if _gaq