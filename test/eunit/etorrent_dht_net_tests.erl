-module(etorrent_dht_net_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-import(etorrent_dht_net, [decode_msg/1,decode_response/2,init_tokens/1,is_valid_token/4,token_value/3]).


fetch_id(Params) ->
    etorrent_bcoding:get_value(<<"id">>, Params).

query_ping_0_test() ->
   Enc = "d1:ad2:id20:abcdefghij0123456789e1:q4:ping1:t2:aa1:y1:qe",
   {ping, ID, Params} = decode_msg(Enc),
   ?assertEqual(<<"aa">>, ID),
   ?assertEqual(<<"abcdefghij0123456789">>, fetch_id(Params)).

query_find_node_0_test() ->
    Enc = "d1:ad2:id20:abcdefghij01234567896:"
        ++"target20:mnopqrstuvwxyz123456e1:q9:find_node1:t2:aa1:y1:qe",
    Res = decode_msg(Enc),
    {find_node, ID, Params} = Res,
    ?assertEqual(<<"aa">>, ID),
    ?assertEqual(<<"abcdefghij0123456789">>, fetch_id(Params)),
    ?assertEqual(<<"mnopqrstuvwxyz123456">>, etorrent_bcoding:get_value(<<"target">>, Params)).

query_get_peers_0_test() ->
    Enc = "d1:ad2:id20:abcdefghij01234567899:info_hash"
        ++"20:mnopqrstuvwxyz123456e1:q9:get_peers1:t2:aa1:y1:qe",
    Res = decode_msg(Enc),
    {get_peers, ID, Params} = Res,
    ?assertEqual(<<"aa">>, ID),
    ?assertEqual(<<"abcdefghij0123456789">>, fetch_id(Params)),
    ?assertEqual(<<"mnopqrstuvwxyz123456">>, etorrent_bcoding:get_value(<<"info_hash">>,Params)).

query_announce_peer_0_test() ->
    Enc = "d1:ad2:id20:abcdefghij01234567899:info_hash20:"
        ++"mnopqrstuvwxyz1234564:porti6881e5:token8:aoeusnthe1:"
        ++"q13:announce_peer1:t2:aa1:y1:qe",
    Res = decode_msg(Enc),
    {announce, ID, Params} = Res,
    ?assertEqual(<<"aa">>, ID),
    ?assertEqual(<<"abcdefghij0123456789">>, fetch_id(Params)),
    ?assertEqual(<<"mnopqrstuvwxyz123456">>, etorrent_bcoding:get_value(<<"info_hash">>,Params)),
    ?assertEqual(<<"aoeusnth">>, etorrent_bcoding:get_value(<<"token">>, Params)),
    ?assertEqual(6881, etorrent_bcoding:get_value(<<"port">>, Params)).

resp_ping_0_test() ->
    Enc = "d1:rd2:id20:mnopqrstuvwxyz123456e1:t2:aa1:y1:re",
    Res = decode_msg(Enc),
    {response, MsgID, Values} = Res,
    ID = decode_response(ping, Values),
    ?assertEqual(<<"aa">>, MsgID),
    ?assertEqual(etorrent_dht:integer_id(<<"mnopqrstuvwxyz123456">>), ID).

resp_find_node_0_test() ->
    Enc = "d1:rd2:id20:0123456789abcdefghij5:nodes0:e1:t2:aa1:y1:re",
    {response, _, Values} = decode_msg(Enc),
    {ID, Nodes} = decode_response(find_node, Values),
    ?assertEqual(etorrent_dht:integer_id(<<"0123456789abcdefghij">>), ID),
    ?assertEqual([], Nodes).

resp_find_node_1_test() ->
    Enc = "d1:rd2:id20:0123456789abcdefghij5:nodes26:"
         ++ "0123456789abcdefghij" ++ [0,0,0,0,0,0] ++ "e1:t2:aa1:y1:re",
    Res = decode_msg(Enc),
    {response, _, Values} = Res,
    {_, Nodes} = decode_response(find_node, Values),
    ?assertEqual([{etorrent_dht:integer_id("0123456789abcdefghij"),
                   {0,0,0,0}, 0}], Nodes).

resp_get_peers_0_test() ->
    Enc = "d1:rd2:id20:abcdefghij01234567895:token8:aoeusnth6:values"
        ++ "l6:axje.u6:idhtnmee1:t2:aa1:y1:re",
    Res = decode_msg(Enc),
    {response, _, Values} = Res,
    {ID, Token, Peers, _Nodes} = decode_response(get_peers, Values),
    ?assertEqual(etorrent_dht:integer_id(<<"abcdefghij0123456789">>), ID),
    ?assertEqual(<<"aoeusnth">>, Token),
    ?assertEqual([{{97,120,106,101},11893}, {{105,100,104,116}, 28269}], Peers).

resp_get_peers_1_test() ->
    Enc = "d1:rd2:id20:abcdefghij01234567895:nodes26:"
        ++ "0123456789abcdefghijdef4565:token8:aoeusnthe"
        ++ "1:t2:aa1:y1:re",
    Res = decode_msg(Enc),
    {response, _, Values} = Res,
    {ID, Token, _Peers, Nodes} = decode_response(get_peers, Values),
    ?assertEqual(etorrent_dht:integer_id(<<"abcdefghij0123456789">>), ID),
    ?assertEqual(<<"aoeusnth">>, Token),
    ?assertEqual([{etorrent_dht:integer_id(<<"0123456789abcdefghij">>),
                   {100,101,102,52},13622}], Nodes).

resp_announce_peer_0_test() ->
    Enc = "d1:rd2:id20:mnopqrstuvwxyz123456e1:t2:aa1:y1:re",
    Res = decode_msg(Enc),
    {response, _, Values} = Res,
    ID = decode_response(announce, Values),
    ?assertEqual(etorrent_dht:integer_id(<<"mnopqrstuvwxyz123456">>), ID).

valid_token_test() ->
    IP = {123,132,213,231},
    Port = 1779,
    TokenValues = init_tokens(10),
    Token = token_value(IP, Port, TokenValues),
    ?assertEqual(true, is_valid_token(Token, IP, Port, TokenValues)),
    ?assertEqual(false, is_valid_token(<<"not there at all!">>,
				       IP, Port, TokenValues)).

-ifdef(PROPER).

-type octet() :: byte().
%-type portnum() :: char().
-type dht_node() :: {{octet(), octet(), octet(), octet()}, portnum()}.
-type integer_id() :: non_neg_integer().
-type node_id() :: integer_id().
-type info_hash() :: integer_id().
%-type token() :: binary().
%-type transaction() ::binary().

-type ping_query() ::
    {ping, transaction(), {{'id', node_id()}}}.

-type find_node_query() ::
   {find_node, transaction(),
        {{'id', node_id()}, {'target', node_id()}}}.

-type get_peers_query() ::
   {get_peers, transaction(),
        {{'id', node_id()}, {'info_hash', info_hash()}}}.

-type announce_query() ::
   {announce, transaction(),
        {{'id', node_id()}, {'info_hash', info_hash()},
         {'token', token()}, {'port', portnum()}}}.

-type dht_query() ::
    ping_query() |
    find_node_query() |
    get_peers_query() |
    announce_query().




prop_inv_compact() ->
   ?FORALL(Input, list(dht_node()),
       begin
           Compact = peers_to_compact(Input),
           Output = compact_to_peers(iolist_to_binary(Compact)),
           Input =:= Output
       end).

prop_inv_compact_test() ->
    qc(prop_inv_compact()).

tobin(Atom) ->
    iolist_to_binary(atom_to_list(Atom)).

prop_query_inv() ->
   ?FORALL(TmpQ, dht_query(),
       begin
           {TmpMethod, TmpMsgId, TmpParams} = TmpQ,
           InQ  = {TmpMethod, <<0, TmpMsgId/binary>>,
                   lists:sort([{tobin(K),V} || {K, V} <- tuple_to_list(TmpParams)])},
           {Method, MsgId, Params} = InQ,
           EncQ = iolist_to_binary(encode_query(Method, MsgId, Params)),
           OutQ = decode_msg(EncQ),
           OutQ =:= InQ
       end).

prop_query_inv_test() ->
    qc(prop_query_inv()).

qc(Gen) ->
    Res = proper:quickcheck(Gen),
    case Res of
        true -> ok;
        Error -> io:format(user, "Proper error: ~p~n", [Error]), error(proper_error)
    end.

-endif. %% EQC
