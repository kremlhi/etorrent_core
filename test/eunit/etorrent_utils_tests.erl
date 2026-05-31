%% Tests for OTP 28 compat changes in etorrent_utils:
%% rand API, crypto API, queue_remove, list_shuffle.
-module(etorrent_utils_tests).
-include_lib("eunit/include/eunit.hrl").

init_random_generator_test() ->
    ?assertEqual(ok, etorrent_utils:init_random_generator()).

sha_test_() ->
    Hash = etorrent_utils:sha(<<"test">>),
    [?_assert(is_binary(Hash)),
     ?_assertEqual(20, byte_size(Hash))].

rand_uniform_test_() ->
    [?_assert(begin V = rand:uniform(), (V > 0.0) andalso (V =< 1.0) end),
     ?_assert(lists:all(fun(V) -> V >= 1 andalso V =< 256 end,
                        [rand:uniform(256) || _ <- lists:seq(1, 100)])),
     ?_assert(begin _ = crypto:rand_seed(), V = rand:uniform(1000),
                    V >= 1 andalso V =< 1000 end)].

queue_remove_test_() ->
    Q = queue:from_list([a, b, c]),
    [?_assertEqual([a, c],    queue:to_list(etorrent_utils:queue_remove(b, Q))),
     ?_assertEqual([a, b, c], queue:to_list(etorrent_utils:queue_remove(z, Q))),
     ?_assertEqual([],        queue:to_list(etorrent_utils:queue_remove(x, queue:new())))].

list_shuffle_test_() ->
    [?_assertEqual(lists:seq(1, 20),
                   lists:sort(etorrent_utils:list_shuffle(lists:seq(1, 20)))),
     ?_assertEqual(50, length(etorrent_utils:list_shuffle(lists:seq(1, 50))))].
