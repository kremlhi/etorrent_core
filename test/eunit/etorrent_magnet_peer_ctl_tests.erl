-module(etorrent_magnet_peer_ctl_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_magnet_peer_ctl, [piece_count/1,piece_count/2,piece_size/3]).


piece_size_test_() ->
    %% 012|345|67-|
    [?_assertEqual(3, piece_size(0, 3, 8))
    ,?_assertEqual(3, piece_size(1, 3, 8))
    ,?_assertEqual(2, piece_size(2, 3, 8))
    %% 012|345|678|
    ,?_assertEqual(3, piece_size(2, 3, 9))
    ].

piece_count_test_() ->
    %% 012|345|6--|
    [?_assertEqual(3, piece_count(3, 7))
    %% 012|345|67-|
    ,?_assertEqual(3, piece_count(3, 8))
    %% 012|345|678|
    ,?_assertEqual(3, piece_count(3, 9))
    ,?_assertEqual(2, piece_count(25356))
    ].

