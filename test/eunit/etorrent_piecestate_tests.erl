-module(etorrent_piecestate_tests).

-include_lib("eunit/include/eunit.hrl").

-define(piecestate, etorrent_piecestate).

%% @todo reuse
flush() ->
    {messages, Msgs} = erlang:process_info(self(), messages),
    [receive Msg -> Msg end || Msg <- Msgs].

piecestate_test_() ->
    {foreach,local,
        fun() -> flush() end,
        fun(_) -> flush() end,
        [?_test(test_notify_pid_list()),
         ?_test(test_notify_piece_list()),
         ?_test(test_invalid()),
         ?_test(test_unassigned()),
         ?_test(test_stored()),
         ?_test(test_valid())]}.

test_notify_pid_list() ->
    ?assertEqual(ok, ?piecestate:invalid(0, [self(), self()])),
    ?assertEqual({piece, {invalid, 0}}, etorrent_utils:first()),
    ?assertEqual({piece, {invalid, 0}}, etorrent_utils:first()).

test_notify_piece_list() ->
    ?assertEqual(ok, ?piecestate:invalid([0,1], self())),
    ?assertEqual({piece, {invalid, 0}}, etorrent_utils:first()),
    ?assertEqual({piece, {invalid, 1}}, etorrent_utils:first()).

test_invalid() ->
    ?assertEqual(ok, ?piecestate:invalid(0, self())),
    ?assertEqual({piece, {invalid, 0}}, etorrent_utils:first()).

test_unassigned() ->
    ?assertEqual(ok, ?piecestate:unassigned(0, self())),
    ?assertEqual({piece, {unassigned, 0}}, etorrent_utils:first()).

test_stored() ->
    ?assertEqual(ok, ?piecestate:stored(0, self())),
    ?assertEqual({piece, {stored, 0}}, etorrent_utils:first()).

test_valid() ->
    ?assertEqual(ok, ?piecestate:valid(0, self())),
    ?assertEqual({piece, {valid, 0}}, etorrent_utils:first()).

