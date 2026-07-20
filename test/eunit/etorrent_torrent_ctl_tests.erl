-module(etorrent_torrent_ctl_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_torrent_ctl, [fetch_hash/2,hashes_to_binary/1,num_hashes/1]).


hashes_to_binary_test_() ->
    Input = [<<1:160>>, <<2:160>>, <<3:160>>],
    Bin = hashes_to_binary(Input),
    [?_assertEqual(<<1:160>>, fetch_hash(0, Bin)),
     ?_assertEqual(<<2:160>>, fetch_hash(1, Bin)),
     ?_assertEqual(<<3:160>>, fetch_hash(2, Bin)),
     ?_assertEqual(3, num_hashes(Bin)),
     ?_assertError(badarg, fetch_hash(-1, Bin)),
     ?_assertError(badarg, fetch_hash(3, Bin))].


