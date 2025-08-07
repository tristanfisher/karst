# default some vars if we don't receive a FOO=bar (or FOO='a bar' on the command line)
IMAGE_NAME?=workstation
# 5901 is the default first port for tigervnc
PORT_MAP=--publish 9080:80/tcp --publish 9901:5901 --publish 9902:5902

LOCAL_LIB_DIR?=~/linux/usr/include
C_LIB_DIR?=/usr/include/.

MOUNT_COMMAND?=--volume `pwd`:/srv/host:ro


## karst application

## docker

# makefile listing from: http://stackoverflow.com/questions/4219255/how-do-you-get-the-list-of-targets-in-a-makefile
default_goal:
	@echo "viable targets:"
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

# -e vnc_password_arg="xxx"
build: clean
	docker build -f ./Dockerfile -t workstation .

run:
	mkdir -p ${LOCAL_LIB_DIR}
	docker run --interactive --tty ${MOUNT_COMMAND} ${PORT_MAP} --name ${IMAGE_NAME} workstation

stop:
	docker stop workstation || true

fresh: stop build run

bg_run:
	docker run ${MOUNT_COMMAND} ${PORT_MAP} --name ${IMAGE_NAME} workstation

shell:
	# todo: if erroring:
	# 	docker exec --interactive --tty workstation /bin/bash
	# 	Error response from daemon: No such container: workstation
	# 	make: *** [shell] Error 1
	# then call `make run`

	docker exec --interactive --tty workstation /bin/bash

cp_lib:
	mkdir -p ${LOCAL_LIB_DIR}
	docker cp workstation:${C_LIB_DIR} ${LOCAL_LIB_DIR}

clean: rm_container rm_image

rm_container:
	docker container rm workstation || true

rm_image:
	docker image rm workstation || true

mac_os_command_vnc_brew:
	echo "#!/usr/bin/env bash\nopen /opt/homebrew/Cellar/tiger-vnc/1.15.0/bin/vncviewer" > ~/Applications/VNC_Viewer.app
	chmod u+x ~/Applications/VNC_Viewer.app
	echo "drag VNC_Viewer.app from ~/Applications to the dock"