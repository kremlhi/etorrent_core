all:
	rebar3 compile

eunit:
	rebar3 eunit

ct:
	rebar3 ct

dialyze:
	rebar3 dialyzer

clean:
	$(RM) -r _build

