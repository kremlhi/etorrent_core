-module(etorrent_io_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_io, [chunk_positions/3,make_piece_map_/2]).

piece_map_0_test() ->
    Size  = 2,
    Files = [{a, 4}],
    Map   = [{a, 0, 0, 2}, {a, 1, 2, 2}],
    ?assertEqual(Map, make_piece_map_(Size, Files)).

piece_map_1_test() ->
    Size  = 2,
    Files = [{a, 2}, {b, 2}],
    Map   = [{a, 0, 0, 2}, {b, 1, 0, 2}],
    ?assertEqual(Map, make_piece_map_(Size, Files)).

piece_map_2_test() ->
    Size  = 2,
    Files = [{a, 3}, {b, 1}],
    Map   = [{a, 0, 0, 2}, {a, 1, 2, 1}, {b, 1, 0, 1}],
    ?assertEqual(Map, make_piece_map_(Size, Files)).

chunk_pos_0_test() ->
    Offs = 1,
    Len  = 3,
    Map  = [{a, 0, 4}],
    Pos  = [{a, 1, 3}],
    ?assertEqual(Pos, chunk_positions(Offs, Len, Map)).

chunk_pos_1_test() ->
    Offs = 2,
    Len  = 4,
    Map  = [{a, 1, 8}],
    Pos  = [{a, 3, 4}],
    ?assertEqual(Pos, chunk_positions(Offs, Len, Map)). 

chunk_pos_2_test() ->
    Offs = 3,
    Len  = 9,
    Map  = [{a, 2, 4}, {b, 0, 10}],
    Pos  = [{a, 5, 1}, {b, 0, 8}],
    ?assertEqual(Pos, chunk_positions(Offs, Len, Map)). 

chunk_post_3_test() ->
    Offs = 8,
    Len  = 5,
    Map  = [{a, 0, 3}, {b, 0, 13}],
    Pos  = [{b, 5, 5}],
    ?assertEqual(Pos, chunk_positions(Offs, Len, Map)). 
    
