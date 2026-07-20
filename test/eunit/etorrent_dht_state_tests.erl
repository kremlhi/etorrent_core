-module(etorrent_dht_state_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_dht_state, [dump_state/3,load_state/1]).


setup() ->
    put(nofile, test_server:temp_name("/tmp/etorrent_test")),
    put(empty,  test_server:temp_name("/tmp/etorrent_test")),
    put(valid,  test_server:temp_name("/tmp/etorrent_test")),
    put(testid, etorrent_dht:random_id()),
    ok = file:write_file(get(empty), <<>>),
    ok = dump_state(get(valid), get(testid), []).

teardown(_) ->
    file:delete(get(empty)),
    file:delete(get(valid)).

dht_state_test_() ->
    {setup, local,
        fun setup/0,
        fun teardown/1,
    [?_test(test_nofile()),
     ?_test(test_empty()),
     ?_test(test_valid())]}.

test_nofile() ->
    Return = load_state(get(nofile)),
    ?assertMatch({_, _}, Return),
    {ID, Nodes} = Return,
    ?assert(is_integer(ID)),
    ?assert(is_list(Nodes)).

test_empty() ->
    Return = load_state(get(empty)),
    ?assertMatch({_, _}, Return),
    {ID, Nodes} = Return,
    ?assert(is_integer(ID)),
    ?assert(is_list(Nodes)).

test_valid() ->
    Return = load_state(get(valid)),
    ?assertMatch({_, _}, Return),
    {ID, Nodes} = Return,
    ?assertEqual(get(testid), ID),
    ?assert(is_list(Nodes)).

