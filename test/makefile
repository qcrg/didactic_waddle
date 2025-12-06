default: hello

text:
	cat text_msg_example.json | jq ".header.timestamp = $(shell date +%s)" | socat -T0 UDP-DATAGRAM:localhost:27676 -

hello:
	cat hello_msg_example.json | jq ".header.timestamp = $(shell date +%s)" | socat -T0 UDP-DATAGRAM:localhost:27676 -

.PHONY: default text hello
