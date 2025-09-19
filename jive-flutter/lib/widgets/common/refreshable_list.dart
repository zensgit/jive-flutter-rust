import 'package:flutter/material.dart';
import '../states/loading_indicator.dart';
import '../states/empty_state.dart';
import '../states/error_state.dart';

/// 可刷新列表组件
class RefreshableList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final Widget? emptyWidget;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final Widget? header;
  final Widget? footer;
  final double loadMoreThreshold;

  const RefreshableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
    this.onLoadMore,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.emptyWidget,
    this.padding,
    this.scrollController,
    this.header,
    this.footer,
    this.loadMoreThreshold = 200.0,
  });

  @override
  State<RefreshableList<T>> createState() => _RefreshableListState<T>();
}

class _RefreshableListState<T> extends State<RefreshableList<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore || widget.onLoadMore == null) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - widget.loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore!();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 错误状态
    if (widget.errorMessage != null && widget.items.isEmpty) {
      return ErrorState(
        message: widget.errorMessage,
        onRetry: widget.onRefresh,
      );
    }

    // 初始加载状态
    if (widget.isLoading && widget.items.isEmpty) {
      return const LoadingIndicator(
        message: '加载中...',
      );
    }

    // 空状态
    if (widget.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: widget.emptyWidget ?? EmptyStates.noData(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 头部
          if (widget.header != null) SliverToBoxAdapter(child: widget.header!),

          // 列表项
          SliverPadding(
            padding: widget.padding ?? EdgeInsets.zero,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return widget.itemBuilder(
                      context, widget.items[index], index);
                },
                childCount: widget.items.length,
              ),
            ),
          ),

          // 加载更多指示器
          if (widget.onLoadMore != null)
            SliverToBoxAdapter(
              child: _buildLoadMoreIndicator(),
            ),

          // 底部
          if (widget.footer != null) SliverToBoxAdapter(child: widget.footer!),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (!widget.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: const Text(
          '没有更多内容了',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
      );
    }

    if (widget.isLoadingMore || _isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: LoadingIndicator(
          size: 24,
          message: '加载更多...',
        ),
      );
    }

    return const SizedBox(height: 16);
  }
}

/// 简单的刷新列表组件
class SimpleRefreshableList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onRefresh;
  final bool isLoading;
  final String? errorMessage;
  final Widget? emptyWidget;
  final EdgeInsetsGeometry? padding;

  const SimpleRefreshableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
    this.emptyWidget,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null && items.isEmpty) {
      return ErrorState(
        message: errorMessage,
        onRetry: onRefresh,
      );
    }

    if (isLoading && items.isEmpty) {
      return const LoadingIndicator(message: '加载中...');
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: emptyWidget ?? EmptyStates.noData(),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return itemBuilder(context, items[index], index);
        },
      ),
    );
  }
}

/// 带搜索的刷新列表组件
class SearchableRefreshableList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String query)? onSearch;
  final bool Function(T item, String query)? localFilter;
  final String? searchHint;
  final bool isLoading;
  final String? errorMessage;
  final Widget? emptyWidget;

  const SearchableRefreshableList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onRefresh,
    this.onSearch,
    this.localFilter,
    this.searchHint,
    this.isLoading = false,
    this.errorMessage,
    this.emptyWidget,
  });

  @override
  State<SearchableRefreshableList<T>> createState() =>
      _SearchableRefreshableListState<T>();
}

class _SearchableRefreshableListState<T>
    extends State<SearchableRefreshableList<T>> {
  final _searchController = TextEditingController();
  List<T> _filteredItems = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(SearchableRefreshableList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items != oldWidget.items) {
      _updateFilteredItems();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredItems = widget.items;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    if (widget.onSearch != null) {
      // 使用远程搜索
      widget.onSearch!(query);
    } else if (widget.localFilter != null) {
      // 使用本地过滤
      _filteredItems = widget.items.where((item) {
        return widget.localFilter!(item, query);
      }).toList();
    }

    setState(() {
      _isSearching = false;
    });
  }

  void _updateFilteredItems() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _filteredItems = widget.items;
    } else if (widget.localFilter != null) {
      _filteredItems = widget.items.where((item) {
        return widget.localFilter!(item, query);
      }).toList();
    } else {
      _filteredItems = widget.items;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.searchHint ?? '搜索...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
          ),
        ),

        // 列表
        Expanded(
          child: SimpleRefreshableList<T>(
            items: _filteredItems,
            itemBuilder: widget.itemBuilder,
            onRefresh: widget.onRefresh,
            isLoading: widget.isLoading || _isSearching,
            errorMessage: widget.errorMessage,
            emptyWidget: _searchController.text.isNotEmpty
                ? EmptyStates.noSearchResults(
                    query: _searchController.text,
                    onClearSearch: () => _searchController.clear(),
                  )
                : widget.emptyWidget,
          ),
        ),
      ],
    );
  }
}
