run: pre_config
	@flutter run

pre_config: set_sway_workspace

set_sway_workspace:
	sway assign [app_id="ru.qcrg.didactic_waddle"] 7

.PHONY: set_sway_workspace run pre_config
