-module(etorrent_ext_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_ext, [filter_supported/3,update_ord_dict/2]).

filter_supported_test_() ->
    [?_assertEqual([{x,{1,yy}},{y,{2,zz}}],
                   filter_supported([{<<"x">>,1}, {<<"y">>,2}, {<<"z">>,3}],
                                    [<<"a">>,<<"x">>,<<"y">>],
                                    [xx,yy,zz]))
    ,?_assertEqual([],
                   filter_supported([],
                                    [<<"a">>],
                                    [xx]))
    ].
update_ord_dict_test_() ->
    [{"Add 3 new extensions."
    ,?_assertEqual(update_ord_dict([{<<"x">>,1}, {<<"y">>,2}, {<<"z">>,3}],
                                    []),
                   [{<<"x">>,1}, {<<"y">>,2}, {<<"z">>,3}])}
    ,{"Add 2 new extension, ignore deletion of the one."
    ,?_assertEqual(update_ord_dict([{<<"x">>,1}, {<<"y">>,0}, {<<"z">>,3}],
                                    []),
                   [{<<"x">>,1}, {<<"z">>,3}])}
    ,{"Add 2 new extension, delete the one."
    ,?_assertEqual(update_ord_dict([{<<"x">>,1}, {<<"y">>,0}, {<<"z">>,3}],
                                    [{<<"y">>,2}]),
                   [{<<"x">>,1}, {<<"z">>,3}])}
%   ,{"Add 2 new extension to a non-empty list, and delete them (strange)."
%   ,?_assertEqual(update_ord_dict([{<<"x">>,1}, {<<"x">>,0}, {<<"z">>,3}, {<<"z">>,0}],
%                                   [{<<"y">>,2}]),
%                  [{<<"y">>,2}])}
    %% Strange case.
    ,{"Delete new extension, and add it."
    ,?_assertEqual(update_ord_dict([{<<"x">>,0}, {<<"x">>,3}],
                                    [{<<"y">>,2}]),
                   [{<<"x">>,3}, {<<"y">>,2}])}
    ].
