-module(etorrent_bcoding_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-ifdef(PROPER).

prop_inv() ->
    ?FORALL(BC, bcode(),
            begin
                Enc = iolist_to_binary(encode(BC)),
                {ok, Dec} = decode(Enc),
                encode(BC) =:= encode(Dec)
            end).

eqc_test() ->
    ?assert(proper:quickcheck(prop_inv())).

-endif.
