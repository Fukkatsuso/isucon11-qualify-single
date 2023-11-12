SERVICE_NAME := isucondition
BUILD_DIR := /home/isucon/webapp/go
ENV_FILE := /home/isucon/env.sh # systemdが読み込むファイル
include $(ENV_FILE)
# SERVER_ID: 環境変数ファイルで定義
SERVER_ENV_FILE = /home/isucon/webapp/env.$(SERVER_ID) # サーバーごとにgit管理するファイル


build:
	cd $(BUILD_DIR); \
	go build -o $(SERVICE_NAME)

deploy:
	# app
	sudo systemctl stop $(SERVICE_NAME).go.service
	cp $(SERVER_ENV_FILE) $(ENV_FILE)
	# 「アプリケーションのsystemdが使用するディレクトリ」以外の場所で開発するときだけ、コメントアウトして使う
	# cp ./webapp/go/$(SERVICE_NAME) /home/isucon/webapp/go
	# cp -r ./webapp/sql /home/isucon/webapp/sql
	sudo systemctl start $(SERVICE_NAME).go.service
	# mysql
	sudo cp ./middleware/$(SERVER_ID)/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
	sudo systemctl restart mysql.service

bench-prepare:
	sudo rm -f /var/log/nginx/access.log
	sudo systemctl reload nginx.service
	sudo rm -f /var/log/mysql/mysql-slow.log
	sudo systemctl restart mysql.service

bench-result:
	mkdir -p alp/dump
	sudo cat /var/log/nginx/access.log \
	| alp ltsv \
	-m '*' \
		--sort avg -r --dump alp/dump/`git show --format='%h' --no-patch` > /dev/null

latest-alp:
	mkdir -p alp/result
	alp ltsv --load alp/dump/`git show --format='%h' --no-patch` > alp/result/`git show --format='%h' --no-patch`
	vim alp/result/`git show --format='%h' --no-patch`

show-slowlog:
	sudo mysqldumpslow /var/log/mysql/mysql-slow.log

show-pt-query-digest:
	sudo pt-query-digest /var/log/mysql/mysql-slow.log

show-applog:
	sudo journalctl -u $(SERVICE_NAME).go.service

enable-pprof:
	sed -i -e 's/PPROF=0/PPROF=1/' $(SERVER_ENV_FILE)

disable-pprof:
	sed -i -e 's/PPROF=1/PPROF=0/' $(SERVER_ENV_FILE)
	echo "*** make deploy で反映してね ***"

start-pprof: enable-pprof deploy
	go tool pprof -http=0.0.0.0:1080 http://localhost:6060/debug/pprof/profile?seconds=80
