extends RefCounted
## AdMob backend for the Ads autoload (Poing Studios godot-admob-plugin 5.x, addons/admob).
## Only created on Android when the native plugin is present, so the plugin's classes are never
## touched on desktop. Flow: UMP consent (GDPR/UK) → MobileAds.initialize → preload one interstitial
## and one rewarded ad; each is reloaded after it is shown or fails.

signal rewarded_earned(reward_id: String)
signal rewarded_failed(reward_id: String)
signal interstitial_closed

var interstitial_id: String = ""
var rewarded_id: String = ""
var ready: bool = false
## Remove Ads owned: nothing loads or shows any more.
var stopped: bool = false

var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _pending_reward: String = ""
var _earned: bool = false


func start() -> void:
	var params: ConsentRequestParameters = ConsentRequestParameters.new()
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	info.update(params, func() -> void:
		if info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
			UserMessagingPlatform.load_consent_form(func(form: ConsentForm) -> void:
				form.show(func(_e: FormError) -> void: _init_sdk()),
				func(_e: FormError) -> void: _init_sdk())
		else:
			_init_sdk(),
		func(_e: FormError) -> void: _init_sdk())


## EEA/UK players must be able to change their ad consent later (Google EU User Consent Policy).
func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
			== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_e: FormError) -> void: pass)


func _init_sdk() -> void:
	if ready:
		return
	var listener: OnInitializationCompleteListener = OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_s: InitializationStatus) -> void:
		ready = true
		print("Ads: AdMob ready")
		load_interstitial()
		load_rewarded()
	var cfg: RequestConfiguration = RequestConfiguration.new()
	cfg.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T  # owner choice: T (13+ game), MA blocked
	MobileAds.set_request_configuration(cfg)
	MobileAds.initialize(listener)


func load_interstitial() -> void:
	if stopped or _interstitial or interstitial_id.is_empty():
		return
	var cb: InterstitialAdLoadCallback = InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		var c: FullScreenContentCallback = FullScreenContentCallback.new()
		c.on_ad_dismissed_full_screen_content = func() -> void: _drop_interstitial()
		c.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: _drop_interstitial()
		ad.full_screen_content_callback = c
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		push_warning("Ads: interstitial failed to load: %s" % e.message)
		_retry(load_interstitial)
	InterstitialAdLoader.new().load(interstitial_id, AdRequest.new(), cb)


func _drop_interstitial() -> void:
	if _interstitial:
		_interstitial.destroy()
	_interstitial = null
	interstitial_closed.emit()
	load_interstitial()


## A failed load is tried again after ads.load_retry_s (no fill, offline).
func _retry(fn: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and not stopped:
		tree.create_timer(float(Data.b("ads", "load_retry_s")), true, false, true).timeout.connect(fn)


func has_interstitial() -> bool:
	return _interstitial != null


## Remove Ads: destroy what is loaded and never load again.
func shutdown() -> void:
	stopped = true
	if _interstitial:
		_interstitial.destroy()
	_interstitial = null
	if _rewarded:
		_rewarded.destroy()
	_rewarded = null


## True when an interstitial was shown.
func show_interstitial() -> bool:
	if _interstitial == null:
		load_interstitial()
		return false
	_interstitial.show()
	return true


func load_rewarded() -> void:
	if stopped or _rewarded or rewarded_id.is_empty():
		return
	var cb: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		var c: FullScreenContentCallback = FullScreenContentCallback.new()
		c.on_ad_dismissed_full_screen_content = func() -> void: _finish_rewarded()
		c.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void: _finish_rewarded()
		ad.full_screen_content_callback = c
	cb.on_ad_failed_to_load = func(e: LoadAdError) -> void:
		push_warning("Ads: rewarded failed to load: %s" % e.message)
		_retry(load_rewarded)
	RewardedAdLoader.new().load(rewarded_id, AdRequest.new(), cb)


func has_rewarded() -> bool:
	return _rewarded != null


func show_rewarded(reward_id: String) -> void:
	if _rewarded == null:
		load_rewarded()
		rewarded_failed.emit.call_deferred(reward_id)
		return
	_pending_reward = reward_id
	_earned = false
	var listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: _earned = true
	_rewarded.show(listener)


## The reward is paid when the ad closes (the game is paused while it is on screen).
func _finish_rewarded() -> void:
	var id: String = _pending_reward
	_pending_reward = ""
	if _rewarded:
		_rewarded.destroy()
	_rewarded = null
	if not id.is_empty():
		if _earned:
			rewarded_earned.emit(id)
		else:
			rewarded_failed.emit(id)
	load_rewarded()
