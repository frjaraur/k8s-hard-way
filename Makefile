destroy:
	@vagrant destroy -f
	@rm -rf tmp_deploying_stage

create:
	@vagrant up -d

recreate:
	@make destroy
	@make create

stop:
	@VBoxManage controlvm k8hw-4 acpipowerbutton || true
	@VBoxManage controlvm k8hw-3 acpipowerbutton || true
	@VBoxManage controlvm k8hw-2 acpipowerbutton || true
	@VBoxManage controlvm k8hw-1 acpipowerbutton || true

start:
	@VBoxManage startvm k8hw-1 --type headless || true
	@sleep 10
	@VBoxManage startvm k8hw-2 --type headless || true
	@VBoxManage startvm k8hw-3 --type headless || true
	@VBoxManage startvm k8hw-4 --type headless || true

status:
	@VBoxManage list runningvms
