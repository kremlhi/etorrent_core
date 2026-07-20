-module(etorrent_monitorset_tests).

-include_lib("eunit/include/eunit.hrl").

-define(monitors, etorrent_monitorset).

empty_size_test() ->
    Set = ?monitors:new(),
    ?assertEqual(0, ?monitors:size(Set)).

insert_increase_size_test() ->
    Set0 = ?monitors:new(),
    Set1 = ?monitors:insert(noop_proc(), 0, Set0),
    Set2 = ?monitors:insert(noop_proc(), 1, Set1),
    ?assertEqual(1, ?monitors:size(Set1)),
    ?assertEqual(2, ?monitors:size(Set2)).

state_value_test() ->
    Set0 = ?monitors:new(),
    Ref0 = noop_proc(),
    Ref1 = noop_proc(),
    Set1 = ?monitors:insert(Ref0, 0, Set0),
    Set2 = ?monitors:insert(Ref1, 1, Set1),
    ?assertEqual(0, ?monitors:fetch(Ref0, Set1)),
    ?assertEqual(1, ?monitors:fetch(Ref1, Set2)).

delete_value_test() ->
    Set0 = ?monitors:new(),
    Ref0 = noop_proc(),
    Ref1 = noop_proc(),
    Set1 = ?monitors:insert(Ref0, 0, Set0),
    Set2 = ?monitors:insert(Ref1, 1, Set1),
    Set3 = ?monitors:delete(Ref0, Set2),
    ?assertEqual(1, ?monitors:fetch(Ref1, Set3)).

is_member_test() ->
    Set0 = ?monitors:new(),
    Ref0 = noop_proc(),
    Ref1 = noop_proc(),
    Set1 = ?monitors:insert(Ref0, 0, Set0),
    Set2 = ?monitors:insert(Ref1, 1, Set1),
    ?assert(?monitors:is_member(Ref0, Set2)),
    ?assert(?monitors:is_member(Ref1, Set2)),
    Set3 = ?monitors:delete(Ref1, Set2),
    ?assert(?monitors:is_member(Ref0, Set3)),
    ?assert(not ?monitors:is_member(Ref1, Set3)).

monitor_one_test() ->
    Set0 = ?monitors:new(),
    Pid  = noop_proc(),
    Set1 = ?monitors:insert(Pid, 0, Set0),
    Pid ! shutdown,
    ?assert(was_monitored(Pid)).

demonitor_one_test() ->
    Set0 = ?monitors:new(),
    Pid  = noop_proc(),
    Set1 = ?monitors:insert(Pid, 0, Set0),
    Set2 = ?monitors:delete(Pid, Set1),
    Pid ! shutdown,
    ?assert(not was_monitored(Pid)).
    

noop_proc() ->
    spawn_link(fun() -> receive shutdown -> ok end end).

was_monitored(Pid) ->
    receive
        {'DOWN', _, _, Pid, _} -> true
        after 100 -> false
    end.
    

