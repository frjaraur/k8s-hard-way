destroy:
	@vagrant destroy -f
	@rm -rf tmp_deploying_stage

create:
	@vagrant up -d

recreate:
	@make destroy
	@make create

stop:
	@VBoxManage controlvm k8hw4 acpipowerbutton || true
	@VBoxManage controlvm k8hw3 acpipowerbutton || true
	@VBoxManage controlvm k8hw2 acpipowerbutton || true
	@VBoxManage controlvm k8hw1 acpipowerbutton || true

start:
	@VBoxManage startvm k8hw1 --type headless || true
	@sleep 10
	@VBoxManage startvm k8hw2 --type headless || true
	@VBoxManage startvm k8hw3 --type headless || true
	@VBoxManage startvm k8hw4 --type headless || true

status:
	@VBoxManage list runningvms
