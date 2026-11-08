extends Node
## Boot: read the save, run migrations, set audio flags, hand over to Splash.
## No network work here - a cold start that waits on DNS loses first sessions.

func _ready() -> void:
	# The autoloads have already loaded the save and the remote-config cache.
	GameManager.state = GameManager.State.BOOT
	RemoteConfigAndAds.request_consent_if_needed()
	GameManager.open_splash()
