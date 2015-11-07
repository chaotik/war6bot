# Description:
#   Interacts with the Bungie Destiny API.
#
# Commands:
#   hubot armory <gamertag> - Returns that players Grimoire Score.
#   hubot played <gamertag> - Returns that players Last played character and lightlevel
#   hubot inventory <gamertag> - Returns that players Last played character's equipped inventory
#   hubot vendor xur - Returns Xur's Inventory or a warning when he isn't available
#

require('dotenv').load()
Deferred = require('promise.coffee').Deferred
DataHelper = require('./bungie-data-helper.coffee')

dataHelper = new DataHelper

module.exports = (robot) ->
  dataHelper.fetchDefs()

  # Returns a grimoire score for a gamertag
  robot.respond /armory (.*)/i, (res) =>
    playerName = res.match[1]

    getPlayerId(res, playerName).then (playerId) ->
      getGrimoireScore(res, playerId).then (grimoireScore) ->
        res.send playerName+'\'s Grimoire Score is: '+grimoireScore

  # Returns an inventory object of last played character for a gamertag
  robot.respond /played (.*)/i, (res) ->
    playerName = res.match[1]

    getPlayerId(res, playerName).then (playerId) ->
      getLastCharacter(res, playerId).then (response) ->
        res.send 'Guardian '+playerName+' last played on their '+response

  # Returns a list of images equipped on the last character for a gamertag
  robot.respond /inventory (.*)/i, (res) ->
    playerName = res.match[1]

    getPlayerId(res, playerName).then (playerId) ->
      getCharacterId(res, playerId).then (characterId) ->
        getCharacterInventory(res, playerId, characterId).then (response) ->
          items = response.map (item) -> dataHelper.parseItemAttachment(item)

          payload =
            message: res.message
            attachments: items

          robot.emit 'slack-attachment', payload

  # Returns a list of items for xur
  robot.respond /vendor xur/i, (res) ->
    getXurInventory(res).then (response) ->
      responseData = response.data

      if not responseData
        res.send 'Xur isn\'t available yet and i gotta wait til he gets here to build it out'
      else
        itemsDefs = response.definitions.items
        itemsCategories = responseData.saleItemCategories
        exoticCategory = itemsCategories.filter (cat) -> cat.categoryTitle == 'Exotic Gear'
        exoticData = exoticCategory[0].saleItems
        itemsData = exoticData.map (exotic) -> dataHelper.serializeFromApi(exotic.item, itemsDefs)

        payload =
          message: res.message
          attachments: dataHelper.parseItemsForAttachment(itemsData)

        robot.emit 'slack-attachment', payload

# Gets general player information from a players gamertag
getPlayerId = (bot, name) ->
  deferred = new Deferred()
  endpoint = 'SearchDestinyPlayer/1/'+name

  makeRequest bot, endpoint, (response) ->
    foundData = response[0]

    if !foundData
      bot.send 'Guardian '+name+' not found :('
      deferred.reject()
      return

    playerId = foundData.membershipId
    deferred.resolve(playerId)

  deferred.promise

# Gets characterId for last character played
getCharacterId = (bot, playerId) ->
  deferred = new Deferred()
  endpoint = '1/Account/'+playerId

  makeRequest bot, endpoint, (response) ->
    data = response.data
    chars = data.characters
    recentChar = chars[0]

    characterId = recentChar.characterBase.characterId
    deferred.resolve(characterId)

  deferred.promise

# Gets Inventory of last played character
getCharacterInventory = (bot, playerId, characterId) ->
  deferred = new Deferred()
  endpoint = '1/Account/'+playerId+'/Character/'+characterId+'/Inventory'
  params = 'definitions=true'

  callback = (response) ->
    definitions = response.definitions.items
    equippable = response.data.buckets.Equippable

    validItems = equippable.map (x) ->
      x.items.filter (item) ->
        item.isEquipped and item.primaryStat

    itemsData = [].concat validItems...

    items = itemsData.map (item) -> dataHelper.serializeFromApi(item, definitions)

    deferred.resolve(items)

  makeRequest(bot, endpoint, callback, params)
  deferred.promise

# Gets genral information about last played character
getLastCharacter = (bot, playerId) ->
  deferred = new Deferred()
  endpoint = '/1/Account/'+playerId
  genderTypes = ['Male', 'Female', 'Unknown']
  raceTypes = ['Human', 'Awoken', 'Exo', 'Unknown']
  classTypes = ['Titan', 'Hunter', 'Warlock', 'Unknown']

  makeRequest bot, endpoint, (response) ->
    data = response.data
    chars = data.characters
    recentChar = chars[0]
    charData = recentChar.characterBase
    levelData = recentChar.levelProgression

    level = levelData.level
    lightLevel = charData.powerLevel
    gender = genderTypes[charData.genderType]
    charClass = classTypes[charData.classType]

    phrase = 'level '+level+' '+gender+' '+charClass+', with a light level of: '+lightLevel
    deferred.resolve(phrase)

  deferred.promise

# Gets a players vendors
getXurInventory = (bot) ->
  deferred = new Deferred()
  endpoint = 'Advisors/Xur'
  params = 'definitions=true'
  callback = (response) ->
    deferred.resolve(response)

  makeRequest(bot, endpoint, callback, params)
  deferred.promise

# Gets a players Grimoire Score from their membershipId
getGrimoireScore = (bot, memberId) ->
  deferred = new Deferred()
  endpoint = '/Vanguard/Grimoire/1/'+memberId

  makeRequest bot, endpoint, (response) ->
    score = response.data.score
    deferred.resolve(score)

  deferred.promise

# Sends GET request from an endpoint, needs a success callback
makeRequest = (bot, endpoint, callback, params) ->
  BUNGIE_API_KEY = process.env.BUNGIE_API_KEY
  baseUrl = 'https://www.bungie.net/Platform/Destiny/'
  trailing = '/'
  queryParams = if params then '?'+params else ''
  url = baseUrl+endpoint+trailing+queryParams

  console.log("url")
  console.log(url)

  bot.http(url)
    .header('X-API-Key', BUNGIE_API_KEY)
    .get() (err, response, body) ->
      object = JSON.parse(body)
      callback(object.Response)
# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

module.exports = (robot) ->

  # robot.hear /lol/i, (res) ->

   #  res.send "lol"
  #
  # robot.respond /open the (.*) doors/i, (res) ->
  #   doorType = res.match[1]
  #   if doorType is "pod bay"
  #     res.reply "I'm afraid I can't let you do that."
  #   else
  #     res.reply "Opening #{doorType} doors"
  #
  # robot.hear /I like pie/i, (res) ->
  #   res.emote "makes a freshly baked pie"
  #
  # lulz = ['lol', 'rofl', 'lmao']
  #
  # robot.respond /lulz/i, (res) ->
  #   res.send res.random lulz
  #
  # robot.topic (res) ->
  #   res.send "#{res.message.text}? That's a Paddlin'"
  #
  #
  # enterReplies = ['Hi', 'Target Acquired', 'Firing', 'Hello friend.', 'Gotcha', 'I see you']
  # leaveReplies = ['Are you still there?', 'Target lost', 'Searching']
  #
  # robot.enter (res) ->
  #   res.send res.random enterReplies
  # robot.leave (res) ->
  #   res.send res.random leaveReplies
  #
  # answer = process.env.HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING
  #
  # robot.respond /what is the answer to the ultimate question of life/, (res) ->
  #   unless answer?
  #     res.send "Missing HUBOT_ANSWER_TO_THE_ULTIMATE_QUESTION_OF_LIFE_THE_UNIVERSE_AND_EVERYTHING in environment: please set and try again"
  #     return
  #   res.send "#{answer}, but what is the question?"
  #
  # robot.respond /you are a little slow/, (res) ->
  #   setTimeout () ->
  #     res.send "Who you calling 'slow'?"
  #   , 60 * 1000
  #
  # annoyIntervalId = null
  #
  # robot.respond /annoy me/, (res) ->
  #   if annoyIntervalId
  #     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #     return
  #
  #   res.send "Hey, want to hear the most annoying sound in the world?"
  #   annoyIntervalId = setInterval () ->
  #     res.send "AAAAAAAAAAAEEEEEEEEEEEEEEEEEEEEEEEEIIIIIIIIHHHHHHHHHH"
  #   , 1000
  #
  # robot.respond /unannoy me/, (res) ->
  #   if annoyIntervalId
  #     res.send "GUYS, GUYS, GUYS!"
  #     clearInterval(annoyIntervalId)
  #     annoyIntervalId = null
  #   else
  #     res.send "Not annoying you right now, am I?"
  #
  #
  # robot.router.post '/hubot/chatsecrets/:room', (req, res) ->
  #   room   = req.params.room
  #   data   = JSON.parse req.body.payload
  #   secret = data.secret
  #
  #   robot.messageRoom room, "I have a secret: #{secret}"
  #
  #   res.send 'OK'
  #
  # robot.error (err, res) ->
  #   robot.logger.error "DOES NOT COMPUTE"
  #
  #   if res?
  #     res.reply "DOES NOT COMPUTE"
  #
  # robot.respond /have a soda/i, (res) ->
  #   # Get number of sodas had (coerced to a number).
  #   sodasHad = robot.brain.get('totalSodas') * 1 or 0
  #
  #   if sodasHad > 4
  #     res.reply "I'm too fizzy.."
  #
  #   else
  #     res.reply 'Sure!'
  #
  #     robot.brain.set 'totalSodas', sodasHad+1
  #
  # robot.respond /sleep it off/i, (res) ->
  #   robot.brain.set 'totalSodas', 0
  #   res.reply 'zzzzz'
