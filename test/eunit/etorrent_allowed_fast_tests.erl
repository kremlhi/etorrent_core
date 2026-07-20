-module(etorrent_allowed_fast_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_allowed_fast, [allowed_fast/4]).


allowed_fast_1_test() ->
    N = 16#AA,
    InfoHash = list_to_binary(lists:duplicate(20, N)),
    {value, PieceSet} = allowed_fast(1313, {80,4,4,200}, 7, InfoHash),
    Pieces = lists:sort(sets:to_list(PieceSet)),
    ?assertEqual([287, 376, 431, 808, 1059, 1188, 1217], Pieces).

allowed_fast_2_test() ->
    N = 16#AA,
    InfoHash = list_to_binary(lists:duplicate(20, N)),
    {value, PieceSet} = allowed_fast(1313, {80,4,4,200}, 9, InfoHash),
    Pieces = lists:sort(sets:to_list(PieceSet)),
    ?assertEqual([287, 353, 376, 431, 508, 808, 1059, 1188, 1217], Pieces).

