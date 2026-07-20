-module(etorrent_metadata_variant_tests).

-include_lib("eunit/include/eunit.hrl").

-define(M, etorrent_metadata_variant).

flow_test() ->
    PeerPid1 = list_to_pid("<0.666.0>"),
    V1 = ?M:new(),
    V2 = ?M:add_peer(PeerPid1, 1, V1),
    PieceNum0 = ?M:request_piece(PeerPid1, V2),
    ?assertEqual(0, PieceNum0),
    {PeerProgress, GlobalProgress, V3} =
        ?M:save_piece(PeerPid1, PieceNum0, <<"data">>, V2),
    ?assertEqual({downloaded, downloaded}, {PeerProgress, GlobalProgress}),
    Data = ?M:extract_data(PeerPid1, V3),
    ?assertEqual([<<"data">>], Data),
    ok.

