-module(etorrent_proto_wire_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-import(etorrent_proto_wire, [extended_msg_contents/5]).


ext_msg_contents_test() ->
    Expected = <<"d1:mde1:pi1729e4:reqqi100e1:v20:Etorrent v-test-casee">>,
    Computed = extended_msg_contents(1729, <<"Etorrent v-test-case">>,
                                     100, {}, []),
    ?assertEqual(Expected, Computed).

