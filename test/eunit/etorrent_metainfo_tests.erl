-module(etorrent_metainfo_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-import(etorrent_metainfo, [get_http_urls/1,is_private/1]).


test_torrent() ->
    [{<<"announce">>,
      <<"http://torrent.ubuntu.com:6969/announce">>},
     {<<"announce-list">>,
      [[<<"http://torrent.ubuntu.com:6969/announce">>],
       [<<"http://ipv6.torrent.ubuntu.com:6969/announce">>]]},
     {<<"comment">>,<<"Ubuntu CD releases.ubuntu.com">>},
     {<<"creation date">>,1286702721},
     {<<"info">>,
      [{<<"length">>,728754176},
       {<<"name">>,<<"ubuntu-10.10-desktop-amd64.iso">>},
       {<<"piece length">>,524288},
       {<<"pieces">>,
	<<34,129,182,214,148,202,7,93,69,98,198,49,204,47,61,
	  110>>}]}].

test_torrent_private() ->
    T = test_torrent(),
    I = [{<<"info">>, IL} || {<<"info">>, IL} <- T],
    H = T -- I,
    P = [{<<"info">>, IL ++ [{<<"private">>, 1}]} || {<<"info">>, IL} <- T],
    H ++ P.
      	  
get_http_urls_test() ->
    ?assertEqual([["http://torrent.ubuntu.com:6969/announce"],
		  ["http://ipv6.torrent.ubuntu.com:6969/announce"]],
		 get_http_urls(test_torrent())).

is_private_test() ->
    ?assertEqual(false, is_private(test_torrent())),
    ?assertEqual(true, is_private(test_torrent_private())).

