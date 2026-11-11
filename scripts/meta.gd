extends RefCounted
## Everything the player keeps between sessions: progress, coins, lives, boosters,
## settings, tutorial flags, and a small play log for playtests.

const SAVE_PATH := "user://save.cfg"
const OLD_SAVE := "user://progress.cfg"
const LOG_PATH := "user://playlog.jsonl"
const MAX_LIVES := 5
const LIFE_SECONDS := 20 * 60
const START_COINS := 300
const PRICES := {"pre_rocket": 100, "pre_scarab": 150, "hammer": 60, "shuffle": 40, "moves5": 90, "refill": 200}
const BOOSTER_NAMES := {"pre_rocket": "Rocket start", "pre_scarab": "Scarab start", "hammer": "Hammer", "shuffle": "Shuffle", "moves5": "+5 Moves"}

var best: Array = []
var coins := START_COINS
var lives := MAX_LIVES
var life_stamp := 0          # unix time the next life started regenerating
var boosters := {"pre_rocket": 1, "pre_scarab": 1, "hammer": 2, "shuffle": 2, "moves5": 1}
var settings := {"music": true, "sound": true, "vibration": true}
var flags := {}              # tutorial / first-time tips already shown
var upload_url := ""         # optional: where play-log events are sent (set in res://config.cfg)
var upload_key := ""

func setup(level_count: int) -> void:
	best.resize(level_count)
	best.fill(0)
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		var b = cf.get_value("p", "best", [])
		for i in mini(b.size(), level_count):
			best[i] = int(b[i])
		coins = int(cf.get_value("p", "coins", START_COINS))
		lives = int(cf.get_value("p", "lives", MAX_LIVES))
		life_stamp = int(cf.get_value("p", "life_stamp", 0))
		var bo = cf.get_value("p", "boosters", {})
		for k in bo:
			boosters[k] = int(bo[k])
		var se = cf.get_value("p", "settings", {})
		for k in se:
			settings[k] = bool(se[k])
		flags = cf.get_value("p", "flags", {})
	else:
		# carry over stars from the first versions of the game
		var old := ConfigFile.new()
		if old.load(OLD_SAVE) == OK:
			var b = old.get_value("progress", "best", [])
			for i in mini(b.size(), level_count):
				best[i] = int(b[i])
	var conf := ConfigFile.new()
	if conf.load("res://config.cfg") == OK:
		upload_url = str(conf.get_value("analytics", "url", ""))
		upload_key = str(conf.get_value("analytics", "key", ""))
	tick_lives()

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "best", best)
	cf.set_value("p", "coins", coins)
	cf.set_value("p", "lives", lives)
	cf.set_value("p", "life_stamp", life_stamp)
	cf.set_value("p", "boosters", boosters)
	cf.set_value("p", "settings", settings)
	cf.set_value("p", "flags", flags)
	cf.save(SAVE_PATH)

func now() -> int:
	return int(Time.get_unix_time_from_system())

# ---------- lives ----------
func tick_lives() -> void:
	if lives >= MAX_LIVES:
		life_stamp = 0
		return
	if life_stamp == 0:
		life_stamp = now()
	var gained := (now() - life_stamp) / LIFE_SECONDS
	if gained > 0:
		lives = mini(MAX_LIVES, lives + gained)
		life_stamp += gained * LIFE_SECONDS
		if lives >= MAX_LIVES:
			life_stamp = 0
		save()

func seconds_to_next_life() -> int:
	if lives >= MAX_LIVES or life_stamp == 0:
		return 0
	return maxi(0, LIFE_SECONDS - (now() - life_stamp))

func lose_life() -> void:
	tick_lives()
	if lives >= MAX_LIVES:
		life_stamp = now()
	lives = maxi(0, lives - 1)
	save()

func refill_lives() -> bool:
	if not spend(PRICES.refill):
		return false
	lives = MAX_LIVES
	life_stamp = 0
	save()
	return true

# ---------- coins and boosters ----------
func spend(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	save()
	return true

func earn(amount: int) -> void:
	coins += amount
	save()

## Use one booster: from the inventory if the player has one, otherwise buy it.
func use_booster(key: String) -> bool:
	if int(boosters.get(key, 0)) > 0:
		boosters[key] -= 1
		save()
		return true
	return spend(PRICES[key])

func can_use(key: String) -> bool:
	return int(boosters.get(key, 0)) > 0 or coins >= PRICES[key]

func seen(flag: String) -> bool:
	return flags.has(flag)

func mark(flag: String) -> void:
	flags[flag] = true
	save()

func unlocked(i: int) -> bool:
	return i == 0 or int(best[i - 1]) > 0

func current_level() -> int:
	for i in best.size():
		if int(best[i]) == 0:
			return i
	return best.size() - 1

# ---------- play log ----------
## One line of JSON per event, kept on the phone and optionally sent to a server.
func log_event(ev: String, data: Dictionary, http_parent: Node = null) -> void:
	var row := data.duplicate()
	row["event"] = ev
	row["t"] = now()
	row["platform"] = OS.get_name()
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify(row))
		f.close()
	if upload_url != "" and http_parent != null:
		var req := HTTPRequest.new()
		http_parent.add_child(req)
		req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free())
		var headers := PackedStringArray(["Content-Type: application/json"])
		if upload_key != "":
			headers.append("apikey: " + upload_key)
			headers.append("Authorization: Bearer " + upload_key)
		req.request(upload_url, headers, HTTPClient.METHOD_POST, JSON.stringify(row))

func log_summary() -> Dictionary:
	# wins / losses per level from the play log, for the stats screen
	var out := {}
	if not FileAccess.file_exists(LOG_PATH):
		return out
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	while f and not f.eof_reached():
		var line := f.get_line()
		if line == "":
			continue
		var d = JSON.parse_string(line)
		if d is Dictionary and d.get("event", "") == "level_end":
			var k := int(d.get("level", 0))
			if not out.has(k):
				out[k] = {"win": 0, "lose": 0}
			out[k]["win" if d.get("result", "") == "won" else "lose"] += 1
	return out
