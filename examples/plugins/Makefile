.PHONY: cpphost nimhost plugin all # always rebuild

all: cpphost nimhost plugin

cpphost: plugin
	$(CXX) $(CPPFLAGS) -o cpphost cpphost.cpp $(shell pkg-config --cflags --libs Qt6Core) $(LDFLAGS)
	./cpphost

nimhost: plugin
	nim c -r nimhost

plugin:
	nim c plugin
