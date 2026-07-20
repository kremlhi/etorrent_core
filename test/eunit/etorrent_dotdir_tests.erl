-module(etorrent_dotdir_tests).

-include_lib("eunit/include/eunit.hrl").

-import(etorrent_dotdir, [info_hash_to_hex/1]).


infohash_test_() ->
    FileName =
    filename:join(code:lib_dir(etorrent_core),
                  "test/etorrent_eunit_SUITE_data/test_file_30M.random.torrent"),
    [?_assertEqual({ok, "87be033150bd8dd1801478a32d4c79e54cb55552"}, 
                   etorrent_dotdir:info_hash(FileName))].


%% @private Update dotdir configuration parameter to point to a new directory.
setup_config() ->
    %% The name must be unique across subtests AND across runs:
    %% erlang:unique_integer/1 restarts per VM, so it alone regenerates
    %% the same names on the next run, inheriting stale directories.
    Uniq = integer_to_list(erlang:unique_integer([positive])),
    Dir = "/tmp/etorrent." ++ os:getpid() ++ "." ++ Uniq,
    ok = meck:new(etorrent_config, []),
    ok = meck:expect(etorrent_config, dotdir, fun () -> Dir end),
    Dir.

%% @private Delete the directory pointed to by the dotdir configuration parameter.
teardown_config(Dir) ->
    ok = meck:unload(etorrent_config),
    file:del_dir_r(Dir),
    ok.

testpath() ->
    filename:join(
      code:lib_dir(etorrent_core),
      "test/etorrent_eunit_SUITE_data/"
      "debian-6.0.2.1-amd64-netinst.iso.torrent").

testhex()  -> "8ed7dab51f46d8ecc2d08dcc1c1ca088ed8a53b4".
testinfo() -> "8ed7dab51f46d8ecc2d08dcc1c1ca088ed8a53b4.info".


dotfiles_test_() ->
    {setup,local,
        fun() -> application:start(gproc) end,
        fun(_) -> application:stop(gproc) end, [
        {foreach,local, 
            fun setup_config/0,
            fun teardown_config/1, [
            ?_test(test_no_torrents()),
            ?_test(test_ensure_exists()),
            test_ensure_exists_error_()] ++
            [{setup,local,
                fun() -> etorrent_dotdir:make() end,
                fun(_) -> ok end,
                [T]} || T <- [
                ?_test(test_copy_torrent()),
                test_copy_torrent_error_(),
                ?_test(test_info_filename()),
                ?_test(test_info_hash()),
                ?_test(test_read_torrent()),
                ?_test(test_read_info()),
                ?_test(test_write_info())]]
        }
    ]}.

test_no_torrents() ->
    ?assertEqual({error, enoent}, etorrent_dotdir:torrents()).

test_ensure_exists() ->
    ?assertNot(etorrent_dotdir:exists(etorrent_config:dotdir())),
    ok = etorrent_dotdir:make(),
    ?assert(etorrent_dotdir:exists(etorrent_config:dotdir())).

test_ensure_exists_error_() ->
    {setup,
        _Setup=fun() ->
        ok = meck:new(file, [unstick,passthrough]),
        ok = meck:expect(file, read_file_info, fun(_) -> {error, enoent} end),
        ok = meck:expect(file, make_dir, fun(_) -> {error, eacces} end)
        end,
        _Teardown=fun(_) -> 
        meck:unload(file)
        end,
        {inorder, [
            ?_assertEqual({error, eacces}, etorrent_dotdir:make()),
            ?_assert(meck:validate(file))]}}.

test_copy_torrent() ->
    ?assertEqual({ok, testhex()}, etorrent_dotdir:copy_torrent(testpath())),
    ?assertEqual({ok, [testhex()]}, etorrent_dotdir:torrents()).

test_copy_torrent_error_() ->
     {setup,
        _Setup=fun() ->
        ok = meck:new(file, [unstick,passthrough]),
        ok = meck:expect(file, copy, fun(_, _) -> {error, eacces} end)
        end,
        _Teardown=fun(_) -> 
        meck:unload(file)
        end,
        {inorder, [
            ?_assertEqual({error, eacces}, etorrent_dotdir:copy_torrent(testpath())),
            ?_assertEqual({ok, []}, etorrent_dotdir:torrents()),
            ?_assert(meck:validate(file))]}}.
   

test_info_filename() ->
    {ok, Infohash} = etorrent_dotdir:copy_torrent(testpath()),
    ?assertEqual(testinfo(), lists:last(filename:split(etorrent_dotdir:info_path(Infohash)))).

test_info_hash() ->
    ?assertEqual({ok, testhex()}, etorrent_dotdir:info_hash(testpath())).

test_read_torrent() ->
    {ok, Infohash} = etorrent_dotdir:copy_torrent(testpath()),
    {ok, Metadata} = etorrent_dotdir:read_torrent(Infohash),
    RawInfohash = etorrent_metainfo:get_infohash(Metadata),
    ?assertEqual(Infohash, info_hash_to_hex(RawInfohash)).

test_read_info() ->
    {ok, Infohash} = etorrent_dotdir:copy_torrent(testpath()),
    {error, enoent} = etorrent_dotdir:read_info(Infohash).

test_write_info() ->
    {ok, Infohash} = etorrent_dotdir:copy_torrent(testpath()),
    ok = etorrent_dotdir:write_info(Infohash, [{<<"a">>, 1}]),
    {ok, [{<<"a">>, 1}]} = etorrent_dotdir:read_info(Infohash).


