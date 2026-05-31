%% Tests for the etorrent_rlimit no-op stub.
%% Verifies the {rlimit, continue} callback contract expected by
%% etorrent_peer_send and etorrent_peer_recv.
-module(etorrent_rlimit_tests).
-include_lib("eunit/include/eunit.hrl").

init_test() ->
    ?assertEqual(ok, etorrent_rlimit:init()).

send_fires_continue_test() ->
    etorrent_rlimit:send(1024),
    receive {rlimit, continue} -> ok
    after 1000 -> ?assert(false)
    end.

recv_fires_continue_test() ->
    etorrent_rlimit:recv(512),
    receive {rlimit, continue} -> ok
    after 1000 -> ?assert(false)
    end.

send_returns_pid_test() ->
    Pid = etorrent_rlimit:send(1),
    receive {rlimit, continue} -> ok after 100 -> ok end,
    ?assert(is_pid(Pid)).

rate_queries_test_() ->
    [?_assertEqual(0,  etorrent_rlimit:send_rate()),
     ?_assertEqual(0,  etorrent_rlimit:recv_rate()),
     ?_assertEqual(0,  etorrent_rlimit:max_send_rate()),
     ?_assertEqual(0,  etorrent_rlimit:max_recv_rate()),
     ?_assertEqual(ok, etorrent_rlimit:max_send_rate(1000)),
     ?_assertEqual(ok, etorrent_rlimit:max_recv_rate(1000))].
