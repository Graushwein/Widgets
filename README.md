## Easy Alerts empowers Beyond All Reason players and spectators with an easy system to create customized unit alerts matching their needs, whether it be with a private/public map ping, chat message, and/or custom sound files. 
* Playing and wanting it to ping where an enemy commander was briefly revealed, or even a reminder (x seconds later) to rebuild a destroyed mex? No problem.
* Casting a match and want an alert when any commander's HP is under x%, an anti/nuke launcher is made and finishes the missile, or even when a commander and other units you designate are loaded into a transport... That's easy! :) (There's separate spectator settings so you can set them without worry about changing things when it is time to play.) 
* Don't want to be spammed by alerts? Well you're in luck, because you can set how often all alerts happen (individually / globally) and only keep the important ones for later, prioritized how you like.
* Questions or want help making an alert? Just put it in the [BAR Discord Easy Alerts thread](https://discord.com/channels/549281623154229250/1394202573828919376/1394202573828919376) and I'll be happy to help.
* Feature requests welcome!
* Streamer/caster wanting help getting the settings exactly the way you want? Shoot me a Discord message.

**Tip**: F5 cycles the camera to previous ping locations.

Just use the premade events and rules like this:
* ``myCommanderRules = {thresholdHP = {reAlertSec=60, mark="Commander In Danger", alertSound="sounds/commands/cmd-selfd.wav", threshMinPerc=.5, priority=0}}``
* ``allyFactoryT2Rules = {finished = {maxAlerts=1, mark="T2 Ally Factory", alertDelay=30, messageTo="allies", messageTxt="T2 Con Please!", sharedAlerts=true}}``

### IMPORTANT: If you are thinking of skipping the rest of this document, take a moment to read this section and the "Event Rules" section. It's short and worth the 30 seconds. 
* By default, all alerts apply to each individual unit separately! sharedAlerts is your friend.
* sharedAlerts and reAlertSec: Understanding/using these will prevent you from spamming yourself with alerts.
* To quickly test your settings, start a game with an AI and play normally. When you want to add/change an alert, pause the game, update and save "Easy_Alerts.lua", press F11, toggle off/on to restart Easy_Alerts, and continue playing. If you make a mistake with a rule, which must be formatted "{event = {rules}}", it will alert you at the top of the game.
* (Most of this is probably obvious to most people, but I find it is always nice to have documentation to reference.)
  
Installation: 
* [Download Easy Alerts](https://github.com/Graushwein/Widgets/archive/refs/tags/1.0.zip)
* Drop "Easy_Alerts.lua" into BAR's "widgets" folder. (...\Beyond-All-Reason\data\LuaUI\Widgets)
* Customizing Alerts: Open the file, customize your rules using the istructions below, save the file.

### The Unit Alert Structure: -- {unitType = {event1 = {rules1}, {event2 = {rules2}}}}
* **Who**: When playing (Player, Ally, Enemy), and spectating (Spectator)
* **Unit Type**: A group of units belonging to a category, like: commander, constructor, groundUnits, and groundT1
* **Event**: A trigger linked to the Unit Type defining what events require Easy Alerts to take action, like: finished, idle, and destroyed. Multiple Events are allowed, but must be unique for the Unit Type.
* Lua is CASE SENSITIVE. Keep that in mind. The code doesn't fix these mistakes.
* Event Rules: Rules linked to the Event defining what should happen when the Event happens, like: reAlertSec, maxAlerts, alertDelay, maxQueueTime, alertSound, and mark

**Who**: (Player, Ally, Enemy), and spectating (Spectator). When player or spectating, only the applicable rules are used.

**Where/How**: Near the top of the "Easy_Alerts.lua" file, you will find the "myCommanderRules" pre-configured example, along with some others.
* The variables are formatted as "[my | ally | enemy | spectator][unitType]Rules". These are where you can customize your alerts, following the examples. 

### Unit Types: If you don't see one that's listed below, it should be in the LONG line under the pre-configured ones.
* Units can have multiple types, like making the commander also have the constructor type.
* When a unit has 2+ types, both with rules for the same event (like if you added idle to the commander), the event with the highest priority is always used.
* If all have same priority, one is randomly chosen. However, depending on your Event Rules, this can lead to both happening right after the other. 
* Premade Unit Types: commander, constructor, factory, factoryT1, factoryT2, factoryT3, rezBot, mex, mexT1, mexT2, energyGen, energyGenT1, energyGenT2, radar, nuke, antiNuke, allMobileUnits, unitsT1, unitsT2, unitsT3, hoverUnits, waterUnits, waterT1, waterT2, waterT3, groundUnits, groundT1, groundT2, groundT3, airUnits, airT1, airT2, airT3

### Unit Events: "created", "finished", "idle", "destroyed", "los", "thresholdHP", "taken", "given", "damaged", "loaded", "stockpile"
* **created**: Starts being built.
* **finished**: Finishes being built.
* **idle**: Has no more orders to follow or units to create. This happens to all units/buildings, including combat units.
* **destroyed**: Unit is destroyed.
* **los**: Line Of Sight. Happens when an enemy unit is fully seen (not on radar) by an allied unit. "enemyCommanderRules" has an example.
* **taken**: Captured. (untested) When you are the player, having the rule in the enemy rules section would alert when you/ally capture it, "my" or "ally" rules would be when the enemy captures it from you/ally. When spectating, it knows based on the teams.
* **given**: Given between allies. (untested) Use "ally" rules to alert when that type is given to you, and "my" rules when you give to an ally. When spectating, it should just work.
* **loaded**: Unit loaded into a transport. Mostly for spectating, or to know your ally is doing it, because enemies usually load up out of sight (meaning BAR doesn't tell you because that'd be cheating). This is why there's a default "los" enemy commander rule.
* **stockpile**: A unit's ammo increases/decreases. Useful to remind you when the nuke is done charging up or being used. Currently, a nuke building for example, it will alert when your/ally's unit is ready to fire AND possibly (depending on the reAlert rule) when it is fired.
* **thresholdHP**: A unit's health percent is below what's defined in the "threshMinPerc" rule, which must be: 0 < "threshMinPerc" < 1.
* ***damaged**: Unit damaged. NOTICE: "damaged" is disabled by default, for very late game performance concerns. (I haven't done any testing though.) I recommend using "thresholdHP" instead of "damaged" events. To enable, go to "function widget:UnitDamaged(" and remove the "--" from all lines in the function block.

### Event Rules: "sharedAlerts", "priority", "reAlertSec", "maxAlerts", "alertDelay", "maxQueueTime", "alertSound", "mark", "ping", "messageTo", "messageTxt", "threshMinPerc"
* **sharedAlerts**: "sharedAlerts=true". Makes the event's rules apply to the entire group instead of individually. Otherwise, for example, the constructor idle event would alert you for each one separately, which you may not want.
* **reAlertSec**: After being alerted, how many seconds it ignore the same event, default=15. Only after reAlertSec will it add it to the alert queue.
* **maxAlerts**: The maximum amount of times you want to be alerted for the unit or unit type (using sharedAlerts).
* **alertDelay**: Seconds to keep the alert in the queue before actually alerting you. (Useful when wanting a large delay and for IDLE events. Idle events can have false positives (BAR related), but it is easily solved with "alertDelay=.1"
* **priority**: Queue priority, default=5. This probably won't happen too often, but if there's multiple queued alerts, it will choose the LOWEST priority. "priority=0" alerts immediately, skipping the queue.
* **maxQueueTime**: Delete alert if queued so long that it probably doesn't apply, default 120. I haven't come up with a reason to use this yet, but maybe someone will.
* **alertSound**: The folder/file path to the sound file within the BAR folders. Easy example, in the same widgets folder as "Easy_Alerts.lua" make the "Easy_Alerts_Sounds" folder to old the sound files. Then use "alertSound='LuaUI/Widgets/Easy_Alerts_Sounds/<fileName>'"
* **mark**: A PERSONAL map ping, only you can see. You can customize the text used for it.
* **ping**: a PUBLIC map ping to all allies or spectators. Be kind and careful when using this. Otherwise, please don't blame me or this widget because I purposely don't use this as an example. So, not my fault you didn't try it out in an AI Game!
* **messageTo**: Who should get a chat message. Choose one: "me", "all", "allies", "spectators". Haven't tested whether BAR has rules around which can be used when.
* **messageTxt**: A message says what?
* **threshMinPerc**: Checks the unit's health every time the code runs. 0 < "threshMinPerc" < 1. Alerts if the HP percent is less.

### General Settings:
* **updateInterval**: How often Easy Alerts should run itself, in addition to when BAR tells it something relevant happened. 1 = 30 times per second and 30 = 1 time per second. Default is once per second, which works great. 60 would run every 2 seconds.
* **minReAlertSec**: Global minimum time it should wait before doing the next queued alert, to prevent a bunch at once, excluding priority 0 alerts.

(There's no warranty. Use at your own risk.)
# THAT'S IT!

"Would you like to know more?"
* For those interested in changing/reusing Easy Alerts code... Great, and feel free! I'm not a professional programmer, but I'm IT adjacent. So, I'd bet this could have been done more efficiently, but I did the best I could...
* When I figure out how to properly do it, Part 2 will further empower users to create game-state related alerts/reminders based on multiple factors/triggers like: game-time, economy, preparedness for newly spotted enemy units (AA), enough AA near fusion farm, radar coverage, and replacing unit losses (like mex/radar)... Recommendations on how best to logic this would be great!

I tried very hard to keep it new modder friendly by having a prototype/class framework and pre-built class methods that black-boxes most of the logic involved. Here's an example:

<img width="917" height="339" alt="image" src="https://github.com/user-attachments/assets/41f7d3a2-935f-4a5e-b577-25b3468a298f" />

* You will notice A LOT of debug lines. I've left these in there for anyone who wants them. I'll remove them as soon as I've fixed the bugs people find, then I'll have the debug version as a separate file to download.

Again, let me know if you have suggestions and questions! 

How to add new unit unitTypes: (types/names not validated)
* Copy/paste a type line below, like "local myMexRules...", change to "exampleRules" varName to be unique and configure the rules using the many examples
* Below in one of the 3 appropriate "track[team]TypesRules", like trackMyTypesRules, add another line like, "example = exampleRules"
* In makeRelTeamDefsRules(), add the appropriate "if" statement for the units and use addToRelTeamDefsRules(unitDefID, "example")

How to add new events:
* Add it to validEvents, like "exampleEvent". Case-sensitive everywhere
* Use it in function/widget, like "widget:UnitIdle()", and do anArmy:hasTypeEventRules(defID, nil, "exampleEvent"), then tell it what to do next, like addUnitToAlertQueue()

How to add new rules:
* Add it to validEventRules, like "exampleRule". Case-sensitive everywhere
* Add it to the return values at the end of getEventRulesNotifyVars() following the examples on that line
* Add its validation rules in validTypeEventRulesTbls() following the examples
* TIP: Most rules are processed in the methods that have "alert" and "queue" in their names
