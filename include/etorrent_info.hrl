%% The file_info record describes one node (file or directory) of a
%% torrent's file tree. It lives in this header so that
%% etorrent_info_tests can construct and inspect records; etorrent_info
%% is its only other user.
-record(file_info, {
    id :: etorrent_types:file_id(),
    parent_id :: etorrent_types:file_id() | undefined,
    %% Level of the node, root level is 0.
    level :: non_neg_integer(),
    %% Relative name, used in file_sup
    name :: string(),
    %% Label for nodes of cascadae file tree
    short_name :: binary(),
    type      = file :: directory | file,
    %% Sorted.
    children  = [] :: [etorrent_types:file_id()],
    %% Ascenders of this node without root-node.
    %% The oldest parent is last.
    parents = [] :: [etorrent_types:file_id()],
    % How many files are in this node?
    capacity  = 0 :: non_neg_integer(),
    size      = 0 :: non_neg_integer(),
    % byte offset from 0
    % for splited directories - the lowest position
    position  = 0 :: non_neg_integer(),
    %% [{Position, Size}]
    byte_ranges :: [{non_neg_integer(), non_neg_integer()}],
    %% Pieces, that contains parts of this file.
    pieces :: etorrent_pieceset:t(),
    %% Pieces, that contains parts of this file only.
    distinct_pieces :: etorrent_pieceset:t()
}).
