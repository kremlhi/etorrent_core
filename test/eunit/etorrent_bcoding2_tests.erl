-module(etorrent_bcoding2_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_bcoding2, [decode/1]).

decode_test_() ->
    [?_assertEqual(decode(<<"d8:msg_typei0e5:piecei0ee">>),
                   {[{<<"msg_type">>, 0}, {<<"piece">>, 0}], <<"">>})].

