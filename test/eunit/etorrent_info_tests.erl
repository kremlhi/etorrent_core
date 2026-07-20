-module(etorrent_info_tests).

-include_lib("eunit/include/eunit.hrl").

-include("etorrent_info.hrl").

%% Keep in sync with the define in etorrent_info.
-define(METADATA_BLOCK_BYTE_SIZE, 16384).

-import(etorrent_info, [add_directories/1,byte_ranges_to_mask/6,byte_to_piece_count_beetween/5,calc_piece_size/4,check_last_piece/4,collect_static_file_info/1,make_mask/4,make_mask/5,mask_to_filelist_int/3,mask_to_size/3,minimize_filelist_priv/2, metadata_pieces/3]).


make_mask_test_() ->
    F = fun etorrent_info:make_mask/4,
    % make_index(From, Size, PLen, TLen)
    %% |0123|4567|89--|
    %% |--xx|x---|----|
    [?_assertEqual(<<2#110:3>>        , F(2, 3,  4, 10))
    %% |012|345|678|9--|
    %% |--x|xx-|---|---|
    ,?_assertEqual(<<2#1100:4>>       , F(2, 3,  3, 10))
    %% |01|23|45|67|89|
    %% |--|xx|x-|--|--|
    ,?_assertEqual(<<2#01100:5>>      , F(2, 3,  2, 10))
    %% |0|1|2|3|4|5|6|7|8|9|
    %% |-|-|x|x|x|-|-|-|-|-|
    ,?_assertEqual(<<2#0011100000:10>>, F(2, 3,  1, 10))
    ,?_assertEqual(<<1:1>>            , F(2, 3, 10, 10))
    ,?_assertEqual(<<1:1, 0:1>>       , F(2, 3,  9, 10))
    %% |012|345|678|9A-|
    %% |xxx|xx-|---|---|
    ,?_assertEqual(<<2#1100:4>>       , F(0, 5,  3, 11))
    %% |012|345|678|9A-|
    %% |---|---|--x|---|
    ,?_assertEqual(<<2#0010:4>>       , F(8, 1,  3, 11))
    %% |012|345|678|9A-|
    %% |---|---|--x|x--|
    ,?_assertEqual(<<2#0011:4>>       , F(8, 2,  3, 11))
    ,?_assertEqual(<<-1:30>>, F(0, 31457279,  1048576, 31457280))
    ,?_assertEqual(<<-1:30>>, F(0, 31457280,  1048576, 31457280))
    ].

make_ungreedy_mask_test_() ->
    F = fun(From, Size, PLen, TLen) -> 
            make_mask(From, Size, PLen, TLen, false) end,
    % make_index(From, Size, PLen, TLen, false)
    %% |0123|4567|89A-|
    %% |--xx|x---|----|
    [?_assertEqual(<<2#000:3>>        , F(2, 3,  4, 11))
    %% |0123|4567|89A-|
    %% |--xx|xxxx|xx--|
    ,?_assertEqual(<<2#010:3>>        , F(2, 8,  4, 11))
    ].

add_directories_test_() ->
    Rec = add_directories(
        [#file_info{position=0, size=3, name="test/t1.txt"}
        ,#file_info{position=3, size=2, name="t2.txt"}
        ,#file_info{position=5, size=1, name="dir1/dir/x.x"}
        ,#file_info{position=6, size=2, name="dir1/dir/x.y"}
        ]),
    Names = el(Rec, #file_info.name),
    Sizes = el(Rec, #file_info.size),
    Positions = el(Rec, #file_info.position),
    Children  = el(Rec, #file_info.children),

    [Root|Elems] = Rec,
    MinNames  = el(simple_minimize_reclist(Elems), #file_info.name),
    
    %% {NumberOfFile, Name, Size, Position, ChildNumbers}
    List = [{0, "",             8, 0, [1, 3, 4]}
           ,{1, "test",         3, 0, [2]}
           ,{2, "test/t1.txt",  3, 0, []}
           ,{3, "t2.txt",       2, 3, []}
           ,{4, "dir1",         3, 5, [5]}
           ,{5, "dir1/dir",     3, 5, [6, 7]}
           ,{6, "dir1/dir/x.x", 1, 5, []}
           ,{7, "dir1/dir/x.y", 2, 6, []}
        ],
    ExpNames = el(List, 2),
    ExpSizes = el(List, 3),
    ExpPositions = el(List, 4),
    ExpChildren  = el(List, 5),
    
    [?_assertEqual(Names, ExpNames)
    ,?_assertEqual(Sizes, ExpSizes)
    ,?_assertEqual(Positions, ExpPositions)
    ,?_assertEqual(Children,  ExpChildren)
    ,?_assertEqual(MinNames, ["test", "t2.txt", "dir1"])
    ].


el(List, Pos) ->
    [element(Pos, X) || X <- List].

%% Return only direct top-level entries (no '/' in name).
simple_minimize_reclist(Elems) ->
    [E || E <- Elems, not lists:member($/, E#file_info.name)].



add_directories_test() ->
    [Root|_] =
    add_directories(
        [#file_info{position=0, size=3, name=
    "BBC.7.BigToe/Eoin Colfer. Artemis Fowl/artemis_04.mp3"}
        ,#file_info{position=3, size=2, name=
    "BBC.7.BigToe/Eoin Colfer. Artemis Fowl. The Arctic Incident/artemis2_03.mp3"}
        ]),
    ?assertMatch(#file_info{position=0, size=5}, Root).

% H = {file_info,undefined,
%           "BBC.7.BigToe/Eoin Colfer. Artemis Fowl. The Arctic Incident/artemis2_03.mp3",
%           undefined,file,[],0,5753284,1633920175,undefined}
% NextDir =  "BBC.7.BigToe/Eoin Colfer. Artemis Fowl/. The Arctic Incident


metadata_pieces_test_() ->
    application:start(crypto),
    TorrentBin = crypto:strong_rand_bytes(100000),
    Pieces = metadata_pieces(TorrentBin, 0, byte_size(TorrentBin)),
    [Last|InitR] = lists:reverse(Pieces),
    F = fun(Piece) -> byte_size(Piece) =:= ?METADATA_BLOCK_BYTE_SIZE end,
    [?_assertEqual(iolist_to_binary(Pieces), TorrentBin)
    ,?_assert(byte_size(Last) =< ?METADATA_BLOCK_BYTE_SIZE)
    ,?_assert(lists:all(F, InitR))
    ].

check_last_piece_test_() ->
    %% Bytes:  |0123|4567|89AB|
    %% Pieces: |0   |1   |2   |
    %% Set:    |---x|xxxx|xxx-|
    [{"The last piece is not full.",
      ?_assertEqual(0, check_last_piece(3, 8, 4, 12))},
    %% Bytes:  |0123|4567|89AB|
    %% Pieces: |0   |1   |2   |
    %% Set:    |---x|xxxx|xxx-|
     {"The last piece has a standard size.",
      ?_assertEqual(0, check_last_piece(3, 9, 4, 12))},
    %% Bytes:  |0123|4567|89A-|
    %% Pieces: |0   |1   |2   |
    %% Set:    |---x|xxxx|xxx-|
    ?_assertEqual(1, check_last_piece(3, 8, 4, 11))
    ].

byte_to_piece_count_beetween_test_() ->
    [?_assertEqual(3, byte_to_piece_count_beetween(3, 8,  4,  20, true))
    ,?_assertEqual(0, byte_to_piece_count_beetween(0, 0,  10, 20, true))
    ,?_assertEqual(1, byte_to_piece_count_beetween(0, 1,  10, 20, true))
    ,?_assertEqual(1, byte_to_piece_count_beetween(0, 9,  10, 20, true))
    ,?_assertEqual(1, byte_to_piece_count_beetween(0, 10, 10, 20, true))
    ,?_assertEqual(2, byte_to_piece_count_beetween(0, 11, 10, 20, true))
    ,?_assertEqual(2, byte_to_piece_count_beetween(1, 10, 10, 20, true))
    ,?_assertEqual(2, byte_to_piece_count_beetween(1, 11, 10, 20, true))

    ,?_assertEqual(1, byte_to_piece_count_beetween(0, 4,  4, 20, false))
    ,?_assertEqual(1, byte_to_piece_count_beetween(3, 8,  4, 20, false))
    ,?_assertEqual(1, byte_to_piece_count_beetween(2030, 1156,
                                                   524288, 600000, true))
    %% From: 2030 Size 1156 PLen 524288 Res -1
    %% test the heuristic.
    ,?_assertEqual(0, byte_to_piece_count_beetween(2030, 1156,
                                                   524288, 600000, false))
   
    %% Bytes:  |0123|4567|89A-|
    %% Pieces: |0   |1   |2   |
    %% Set:    |----|----|xxx-|
    ,?_assertEqual(1, byte_to_piece_count_beetween(8, 3, 4, 11, false))
    %% Bytes:  |0123|4567|89A-|
    %% Pieces: |0   |1   |2   |
    %% Set:    |----|----|xx--|
    ,?_assertEqual(0, byte_to_piece_count_beetween(8, 2, 4, 11, false))
    ].

mask_to_size_test_() ->
    %% Ids:    |01234|
    %% Pieces: |----x|
    [?_assert(etorrent_pieceset:is_member(4, etorrent_pieceset:from_list([4], 5)))
    %% TLen: 18, PLen: 4, PCount: 5
    %% Bytes: 3*4 + 2
    %% Ids:    |01234|
    %% Pieces: |-xx--|
    %% Selected: 2*4
    ,?_assertEqual(8, mask_to_size(etorrent_pieceset:from_list([1,2], 5), 18, 4))
    %% Ids:    |01234|
    %% Pieces: |-xx-x|
    %% Selected: 2*4+2
    ,?_assertEqual(10, mask_to_size(etorrent_pieceset:from_list([1,2,4], 5), 18, 4))
    %% Ids:    |01234|
    %% Pieces: |----x|
    %% Selected: 2
    ,?_assertEqual(2, mask_to_size(etorrent_pieceset:from_list([4], 5), 18, 4))
    %% Ids:    |01234|
    %% Pieces: |x----|
    %% Selected: 4
    ,?_assertEqual(4, mask_to_size(etorrent_pieceset:from_list([0], 5), 18, 4))
    ,{"All pieces have the same size." %% 2 last pieces are selected.
     ,?_assertEqual(20, mask_to_size(etorrent_pieceset:from_list([8,9], 10), 100, 10))}
    ].


unordered_mask_to_filelist_int_ungreedy_test_() ->
    FileName = filename:join(code:lib_dir(etorrent_core), 
                             "test/etorrent_eunit_SUITE_data/malena.torrent"),
    {ok, Torrent} = etorrent_bcoding:parse_file(FileName),
    Info = collect_static_file_info(Torrent),
    TorrentName = "Malena Ernmann 2009 La Voux Du Nord (2CD)",
    {Arr, _PLen, _TLen, _} = Info,
    List = lists:keysort(#file_info.size, array:sparse_to_list(Arr)),
    N2I     = file_name_to_ids(Arr),
    FileId  = fun(Name) -> dict:fetch(TorrentName ++ "/" ++ Name, N2I) end,
    Pieces  = fun(Id) -> #file_info{pieces=Ps} = array:get(Id, Arr), Ps end,
    GetName = fun(Id) -> #file_info{name=N} = array:get(Id, Arr), N end,
    CD1     = FileId("CD1 PopWorks"),
    Flac1   = FileId("CD1 PopWorks/Malena Ernman - La Voix Du Nord - PopWorks (CD 1).flac"),
    Log1    = FileId("CD1 PopWorks/Malena Ernman - La Voix Du Nord - PopWorks (CD 1).log"),
    Cue1    = FileId("CD1 PopWorks/Malena Ernman - La Voix Du Nord - PopWorks (CD 1).cue"),
    AU1     = FileId("CD1 PopWorks/Folder.auCDtect.txt"),

    CD2     = FileId("CD2 Arias"),
    AU2     = FileId("CD2 Arias/Folder.auCDtect.txt"),
    Flac2   = FileId("CD2 Arias/Malena Ernman - La Voix Du Nord - Arias (CD 2).flac"),
    Log2    = FileId("CD2 Arias/Malena Ernman - La Voix Du Nord - Arias (CD 2).log"),
    Cue2    = FileId("CD2 Arias/Malena Ernman - La Voix Du Nord - Arias (CD 2).cue"),
    AU2     = FileId("CD2 Arias/Folder.auCDtect.txt"),
    CD2Pieces   = Pieces(CD2),
    Flac2Pieces  = Pieces(Flac2),
    Log2Pieces   = Pieces(Log2),
    Cue2Pieces   = Pieces(Cue2),
    AU2Pieces    = Pieces(AU2),
    UnionCD2Pieces = etorrent_pieceset:union([Flac2Pieces, Log2Pieces,
                                              Cue2Pieces, AU2Pieces]),
    [{"Tiny files are not wanted, but will be downloaded too.",
      [?_assertEqual([Log1, Cue1, AU1, CD2],
                     mask_to_filelist_int(UnionCD2Pieces, Arr, false))
      ,?_assertEqual([Log1, Cue1, AU1, CD2],
                     mask_to_filelist_int(CD2Pieces, Arr, false))
      ,?_assertEqual([CD2],
                     minimize_filelist_priv([AU2, Flac2, Log2, Cue2], Arr))
      ,?_assertEqual([CD2],
                     minimize_filelist_priv([AU2, Flac2, Log2, Cue2, CD2], Arr))
      ,?_assertEqual([CD2],
                     minimize_filelist_priv([AU2, Cue2, CD2], Arr))
      ,?_assertEqual([0],
                     minimize_filelist_priv([AU2, Flac2, Log2, Cue2, 0], Arr))
      ]}
    ].

mask_to_filelist_int_test_() ->
    FileName = filename:join(code:lib_dir(etorrent_core), 
                             "test/etorrent_eunit_SUITE_data/coulton.torrent"),
    {ok, Torrent} = etorrent_bcoding:parse_file(FileName),
    Info = collect_static_file_info(Torrent),
    {Arr, _PLen, _TLen, _} = Info,
    N2I     = file_name_to_ids(Arr),
    FileId  = fun(Name) -> dict:fetch(Name, N2I) end,
    Pieces  = fun(Id) -> #file_info{pieces=Ps} = array:get(Id, Arr), Ps end,
    Week4   = FileId("Jonathan Coulton/Thing a Week 4"),
    BigBoom = FileId("Jonathan Coulton/Thing a Week 4/The Big Boom.mp3"),
    Ikea    = FileId("Jonathan Coulton/Smoking Monkey/04 Ikea.mp3"),
    Week4Pieces   = Pieces(Week4),
    BigBoomPieces = Pieces(BigBoom),
    IkeaPieces    = Pieces(Ikea),
    W4BBPieces    = etorrent_pieceset:union(Week4Pieces, BigBoomPieces),
    W4IkeaPieces  = etorrent_pieceset:union(Week4Pieces, IkeaPieces),
    [?_assertEqual([Week4], mask_to_filelist_int(Week4Pieces, Arr, true))
    ,?_assertEqual([Week4], mask_to_filelist_int(W4BBPieces, Arr, true))
    ,?_assertEqual([Ikea, Week4], mask_to_filelist_int(W4IkeaPieces, Arr, true))
    ].

mask_to_filelist_int_ungreedy_test_() ->
    FileName = filename:join(code:lib_dir(etorrent_core), 
               "test/etorrent_eunit_SUITE_data/joco2011-03-25.torrent"),
    {ok, Torrent} = etorrent_bcoding:parse_file(FileName),
    Info = collect_static_file_info(Torrent),
    {Arr, _PLen, _TLen, _} = Info,
    N2I     = file_name_to_ids(Arr),
    FileId  = fun(Name) -> dict:fetch(Name, N2I) end,
    Pieces  = fun(Id) -> #file_info{pieces=Ps, distinct_pieces=DPs} = 
                            array:get(Id, Arr), {Ps, DPs} end,
    T01     = FileId("joco2011-03-25/joco-2011-03-25t01.flac"),
    TXT     = FileId("joco2011-03-25/joco2011-03-25.txt"),
    FFP     = FileId("joco2011-03-25/joco2011-03-25.ffp"),

    {T01Pieces, T01DisPieces} = Pieces(T01),
    [{"Large file overlaps small files."
     ,?_assertEqual(lists:sort([FFP, TXT, T01]),
                    lists:sort(mask_to_filelist_int(T01Pieces, Arr, true)))}
    ,?_assert(T01Pieces =/= T01DisPieces)
    ,{"Match by distinct pieces."
     ,?_assertEqual([T01], mask_to_filelist_int(T01DisPieces, Arr, false))}
    ,{"Match by distinct pieces. Test for mask_to_filelist_rec_tiny_file."
    ,?_assertEqual(lists:sort([FFP, TXT, T01]),
                   lists:sort(mask_to_filelist_int(T01Pieces, Arr, false)))}
    ].

file_name_to_ids(Arr) ->
    F = fun(FileId, #file_info{name=Name}, Acc) -> [{Name, FileId}|Acc] end,
    dict:from_list(array:sparse_foldl(F, [], Arr)).


byte_ranges_to_mask_test_() ->
    %% Bytes:  |0123|4567|89AB|
    %% Pieces: |0   |1   |2   |
    %% Set:    |---x|xxxx|xxx-|
    [?_assertEqual(<<2#010:3>>, byte_ranges_to_mask([{3,8}], 0, 4, 12,
                                                    false, <<>>)),
    %% Bytes:  |0123|4567|89AB|
    %% Pieces: |0   |1   |2   |
    %% Set:    |---x|xxxx|xxxx|
     ?_assertEqual(<<2#011:3>>, byte_ranges_to_mask([{3,9}], 0, 4, 12,
                                                    false, <<>>)),
    %% Bytes:  |0123|4567|89A-|
    %% Pieces: |0   |1   |2   |
    %% Set:    |---x|xxxx|xxx-|
     ?_assertEqual(<<2#011:3>>, byte_ranges_to_mask([{3,8}], 0, 4, 11,
                                                    false, <<>>))
    ].


calc_piece_size_test_() ->
    %% PieceNum, PieceSize, TotalSize, PieceCount
    %% Bytes:  |0123|4567|89AB|
    %% Pieces: |0   |1   |2   |
    [?_assertEqual(4, calc_piece_size(0, 4, 12, 3)),
     ?_assertEqual(4, calc_piece_size(1, 4, 12, 3)),
     ?_assertEqual(4, calc_piece_size(2, 4, 12, 3)),
     ?_assertError(function_clause, calc_piece_size(3, 4, 12, 3)),
     ?_assertError(function_clause, calc_piece_size(-1, 4, 12, 3)),

    %% Bytes:  |0123|4567|89A-|
    %% Pieces: |0   |1   |2   |
     ?_assertEqual(4, calc_piece_size(0, 4, 11, 3)),
     ?_assertEqual(4, calc_piece_size(1, 4, 11, 3)),
     ?_assertEqual(3, calc_piece_size(2, 4, 11, 3))
    ].

