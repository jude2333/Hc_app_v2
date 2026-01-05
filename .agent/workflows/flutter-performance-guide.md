---
description: Flutter Performance Optimization - Complete Reference Guide
---

# 🚀 Flutter Performance Optimization Guide

A comprehensive reference for building fast, responsive Flutter applications.

---

## Table of Contents

1. [Understanding the Problem](#1-understanding-the-problem)
2. [Non-Blocking Initialization](#2-non-blocking-initialization)
3. [Future.microtask() Explained](#3-futuremicrotask-explained)
4. [Tab Caching with AutomaticKeepAliveClientMixin](#4-tab-caching)
5. [Loading State Management](#5-loading-state-management)
6. [Skeleton Loading](#6-skeleton-loading)
7. [Isolates with compute()](#7-isolates-with-compute)
8. [Widget Build Optimization](#8-widget-build-optimization)
9. [Memory Management & Disposal](#9-memory-management--disposal)
10. [Riverpod-Specific Patterns](#10-riverpod-specific-patterns)
11. [Complete Do's and Don'ts](#11-complete-dos-and-donts)
12. [Performance Checklist](#12-performance-checklist)
13. [Real-World Examples from This Project](#13-real-world-examples)

---

## 1. Understanding the Problem

### How Flutter Rendering Works

Flutter runs on a **single UI thread** (main thread). This thread is responsible for:

- Building widgets
- Handling user input
- Running your Dart code
- Painting frames (60fps = 16ms per frame)

```
┌─────────────────────────────────────────────────────────────┐
│                    MAIN THREAD TIMELINE                     │
│                                                             │
│  Frame 1    Frame 2    Frame 3    Frame 4    Frame 5       │
│  [16ms]     [16ms]     [16ms]     [16ms]     [16ms]        │
│    ↓          ↓          ↓          ↓          ↓           │
│  Build     Build      Build      Build      Build          │
│  Layout    Layout     Layout     Layout     Layout         │
│  Paint     Paint      Paint      Paint      Paint          │
│                                                             │
│  SMOOTH 60fps ✅                                            │
└─────────────────────────────────────────────────────────────┘
```

### What Causes Freezes?

When you do **blocking work** on the main thread, frames can't be painted:

```
┌─────────────────────────────────────────────────────────────┐
│                    BLOCKED TIMELINE                         │
│                                                             │
│  Frame 1    [HTTP REQUEST - 2 SECONDS]     Frame 2         │
│  [16ms]     ████████████████████████████   [16ms]          │
│    ↓                    ↓                    ↓              │
│  Build           NOTHING PAINTS!           Build           │
│  Layout          USER SEES FREEZE          Layout          │
│  Paint           🥶🥶🥶🥶🥶🥶🥶🥶          Paint           │
│                                                             │
│  FROZEN UI ❌                                               │
└─────────────────────────────────────────────────────────────┘
```

### Common Causes of Freezes

| Cause                       | Example                      | Solution                         |
| --------------------------- | ---------------------------- | -------------------------------- |
| HTTP requests in initState  | `await http.get()`           | `Future.microtask()`             |
| Database initialization     | `await db.open()`            | Non-blocking init with Completer |
| JSON parsing large data     | `json.decode(bigString)`     | `compute()` isolate              |
| Heavy calculations in build | `items.map().where().sort()` | Pre-compute in state             |
| Creating objects in build   | `TextEditingController()`    | Create in initState              |

---

## 2. Non-Blocking Initialization

### The Problem

`initState()` runs **before** the first frame is painted. If you await anything, the user sees nothing.

```dart
// ❌ BAD - UI frozen until HTTP completes
@override
void initState() {
  super.initState();
  _loadData();  // Even without await, the first setState blocks
}

Future<void> _loadData() async {
  setState(() => _isLoading = true);  // This triggers a rebuild

  // But we're about to block for 2 seconds!
  final response = await http.get(Uri.parse('https://api.example.com/data'));

  // User saw NOTHING for 2 seconds
  setState(() {
    _data = response.body;
    _isLoading = false;
  });
}
```

### The Solution

```dart
// ✅ GOOD - UI renders immediately, then data loads
@override
void initState() {
  super.initState();

  // Schedule the work to happen AFTER this sync code completes
  Future.microtask(() => _loadData());
}

Future<void> _loadData() async {
  if (_isLoading) return;  // Prevent duplicate calls

  setState(() => _isLoading = true);  // UI shows skeleton

  try {
    final response = await http.get(Uri.parse('https://api.example.com/data'));

    if (mounted) {  // Check if widget still exists
      setState(() {
        _data = response.body;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }
}
```

### Timeline Comparison

```
❌ WITHOUT Future.microtask():
┌─────────────────────────────────────────────────────────────┐
│ initState() → setState(loading=true) → WAIT 2s → setState  │
│                                         ↑                   │
│                                    USER SEES NOTHING        │
└─────────────────────────────────────────────────────────────┘

✅ WITH Future.microtask():
┌─────────────────────────────────────────────────────────────┐
│ initState() → Schedule microtask → build() → PAINT FRAME   │
│                                                ↓            │
│                                    USER SEES SKELETON!      │
│                                                             │
│ [Later] Microtask runs → HTTP → setState → PAINT NEW DATA  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Future.microtask() Explained

### Dart Event Loop Overview

Dart has an **event loop** with two queues:

```
┌─────────────────────────────────────────────────────────────┐
│                     DART EVENT LOOP                         │
│                                                             │
│  ┌─────────────────┐                                        │
│  │ MICROTASK QUEUE │  ← High priority, runs first          │
│  │  (internal)     │                                        │
│  └────────┬────────┘                                        │
│           ↓                                                 │
│  ┌─────────────────┐                                        │
│  │  EVENT QUEUE    │  ← Timer callbacks, I/O, gestures     │
│  │  (external)     │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

### Different Scheduling Methods

```dart
// 1. Future.microtask() - Runs after current sync code, before next event
Future.microtask(() {
  print('Microtask');
});

// 2. Future.delayed() - Runs after specified duration
Future.delayed(Duration(milliseconds: 100), () {
  print('Delayed');
});

// 3. scheduleMicrotask() - Same as Future.microtask, lower level
scheduleMicrotask(() {
  print('Scheduled microtask');
});

// 4. WidgetsBinding.addPostFrameCallback() - After frame is painted
WidgetsBinding.instance.addPostFrameCallback((_) {
  print('Frame painted');
});

// Execution order:
// 1. Current sync code
// 2. Microtasks (in order)
// 3. Next event (timer, I/O, etc.)
// 4. Post-frame callbacks (after paint)
```

### When to Use Each

| Method                          | When                   | Example                           |
| ------------------------------- | ---------------------- | --------------------------------- |
| `Future.microtask()`            | Non-blocking init      | Loading data on page open         |
| `addPostFrameCallback()`        | Need BuildContext/size | Scrolling to position after build |
| `Future.delayed(Duration.zero)` | Same as microtask      | (Avoid, use microtask instead)    |
| `Future.delayed(Duration(...))` | Intentional delay      | Animation sequencing              |

---

## 4. Tab Caching with AutomaticKeepAliveClientMixin {#4-tab-caching}

### The Problem

When using `TabBarView`, Flutter destroys tab content when you switch away:

```dart
TabBarView(
  children: [
    DailyTab(),    // Created, then DESTROYED when you switch
    WeeklyTab(),   // Created fresh each time you switch back
    MonthlyTab(),
  ],
)
```

This means:

- Data is re-fetched every tab switch
- Scroll position is lost
- User sees loading again

### The Solution

```dart
class _DailyTabState extends ConsumerState<DailyTab>
    with AutomaticKeepAliveClientMixin {  // ← Step 1: Add mixin

  @override
  bool get wantKeepAlive => true;  // ← Step 2: Return true

  @override
  Widget build(BuildContext context) {
    super.build(context);  // ← Step 3: MUST call super.build!

    return YourContent();
  }
}
```

### What It Does

```
WITHOUT AutomaticKeepAliveClientMixin:
┌─────────────────────────────────────────────────────────────┐
│ Tab 1 (Active)  →  Switch to Tab 2  →  Switch back to Tab 1│
│   [Created]          [Tab 1 DESTROYED]    [Tab 1 CREATED]  │
│   [Fetch data]       [Data GONE]          [Fetch AGAIN]    │
└─────────────────────────────────────────────────────────────┘

WITH AutomaticKeepAliveClientMixin:
┌─────────────────────────────────────────────────────────────┐
│ Tab 1 (Active)  →  Switch to Tab 2  →  Switch back to Tab 1│
│   [Created]          [Tab 1 HIDDEN]       [Tab 1 SHOWN]    │
│   [Fetch data]       [Data PRESERVED]     [INSTANT!]       │
└─────────────────────────────────────────────────────────────┘
```

### Important Notes

1. **Must call `super.build(context)`** - Forgetting this breaks the mixin
2. **Memory trade-off** - Tabs stay in memory (usually fine for 4-5 tabs)
3. **Use `hasLoadedOnce` flag** - Prevents unnecessary skeleton on revisit

---

## 5. Loading State Management

### Simple Pattern

```dart
class _MyPageState extends State<MyPage> {
  bool _isLoading = false;
  bool _hasLoadedOnce = false;  // Track first load
  List<Item> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());
  }

  Future<void> _loadData() async {
    if (_isLoading) return;  // Prevent duplicate calls

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await api.fetchItems();

      if (mounted) {
        setState(() {
          _items = items;
          _hasLoadedOnce = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _hasLoadedOnce = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // First time loading → skeleton
    if (_isLoading && !_hasLoadedOnce) {
      return SkeletonLoading();
    }

    // Refreshing → show spinner over content
    if (_isLoading) {
      return Stack(
        children: [
          _buildContent(),
          CircularProgressIndicator(),
        ],
      );
    }

    // Error state
    if (_error != null) {
      return ErrorWidget(
        message: _error!,
        onRetry: _loadData,
      );
    }

    // Empty state
    if (_items.isEmpty) {
      return EmptyState(onRefresh: _loadData);
    }

    // Normal content
    return _buildContent();
  }
}
```

### State Flow Diagram

```
┌───────────────────────────────────────────────────────────────┐
│                       STATE FLOW                              │
│                                                               │
│  ┌─────────┐    Success    ┌─────────┐                       │
│  │ Initial │─────────────→ │ Content │                       │
│  │ Loading │               │ Loaded  │                       │
│  └────┬────┘               └────┬────┘                       │
│       │                         │                             │
│       │ Error                   │ Refresh                     │
│       ↓                         ↓                             │
│  ┌─────────┐               ┌─────────┐                       │
│  │  Error  │               │Refreshing│                      │
│  │  State  │               │(spinner) │                      │
│  └────┬────┘               └─────────┘                       │
│       │                                                       │
│       │ Retry                                                 │
│       ↓                                                       │
│  Back to Initial Loading                                      │
└───────────────────────────────────────────────────────────────┘
```

---

## 6. Skeleton Loading

### Why Skeletons > Spinners

| Aspect          | Spinner                | Skeleton                   |
| --------------- | ---------------------- | -------------------------- |
| Visual feedback | "Something is loading" | "This is what will appear" |
| Perceived speed | Feels slow             | Feels fast                 |
| Layout shift    | Content pops in        | Smooth transition          |
| User anxiety    | "Is it broken?"        | "I can see it's working"   |

### Implementation

```dart
class SkeletonLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mimic the header
        ShimmerBox(width: 120, height: 24),
        SizedBox(height: 16),

        // Mimic the content cards
        Row(
          children: [
            Expanded(child: SkeletonCard()),
            SizedBox(width: 12),
            Expanded(child: SkeletonCard()),
          ],
        ),
        SizedBox(height: 12),

        // Mimic the list items
        ...List.generate(5, (i) => SkeletonListItem()),
      ],
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;

  const ShimmerBox({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(width: 60, height: 12),
          SizedBox(height: 8),
          ShimmerBox(width: 100, height: 20),
        ],
      ),
    );
  }
}
```

### Animated Shimmer Effect (Advanced)

```dart
class AnimatedShimmer extends StatefulWidget {
  final Widget child;

  const AnimatedShimmer({required this.child});

  @override
  _AnimatedShimmerState createState() => _AnimatedShimmerState();
}

class _AnimatedShimmerState extends State<AnimatedShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
```

---

## 7. Isolates with compute()

### When to Use Isolates

**Use `compute()` when:**

- Parsing JSON > 50KB
- Processing lists > 1000 items
- Any operation taking > 16ms

**Don't use for:**

- Simple API calls (Dart async handles this)
- Small data transformations
- UI-related work (isolates can't access UI)

### Basic Usage

```dart
// ❌ BAD - Parsing on main thread
Future<void> _loadData() async {
  final response = await http.get(url);

  // This blocks the UI if JSON is large!
  final items = jsonDecode(response.body)
      .map((e) => Item.fromJson(e))
      .toList();

  setState(() => _items = items);
}

// ✅ GOOD - Parsing in isolate
Future<void> _loadData() async {
  final response = await http.get(url);

  // This runs on a separate thread!
  final items = await compute(_parseItems, response.body);

  setState(() => _items = items);
}

// Top-level function (required for compute)
List<Item> _parseItems(String jsonString) {
  return (jsonDecode(jsonString) as List)
      .map((e) => Item.fromJson(e))
      .toList();
}
```

### Important Rules for compute()

```dart
// 1. Function MUST be top-level or static
// ❌ BAD - Instance method
class MyClass {
  List<Item> parseItems(String json) { ... }  // Won't work!
}

// ✅ GOOD - Top-level function
List<Item> parseItems(String json) { ... }

// ✅ GOOD - Static method
class Parser {
  static List<Item> parseItems(String json) { ... }
}

// 2. Arguments must be serializable (no closures)
// ❌ BAD
final callback = () => print('hi');
compute(doWork, callback);  // Won't work!

// ✅ GOOD - Pass simple data
compute(doWork, jsonString);

// 3. Return value must be serializable
// ❌ BAD - Returning a Stream
compute(createStream, data);  // Won't work!

// ✅ GOOD - Return List, Map, or custom serializable class
compute(parseToList, data);
```

### Real Example from This Project

```dart
// In work_order_provider.dart

// Top-level function for isolate
List<WorkOrder> _parseWorkOrdersIsolate(List<dynamic> rows) {
  return rows.map((row) {
    return WorkOrder.fromMap(row);  // Pre-computed values in model
  }).toList();
}

// Usage in provider
_ordersSubscription = _powerSync
    .watchWorkOrdersByDate(selectedDate)
    .asyncMap((rawRows) async {
      // Heavy parsing runs in isolate!
      return await compute(_parseWorkOrdersIsolate, rawRows);
    })
    .listen((orders) {
      _workOrders = orders;
      notifyListeners();
    });
```

---

## 8. Widget Build Optimization

### The build() Method Runs Often

`build()` is called:

- On `setState()`
- When parent rebuilds
- On hot reload
- When keyboard appears/disappears
- When dependencies change (InheritedWidget, Provider, etc.)

**Never do expensive work in build()!**

### ❌ Anti-Patterns

```dart
@override
Widget build(BuildContext context) {
  // ❌ Creating controllers - new instance every rebuild!
  final controller = TextEditingController();

  // ❌ Heavy computation - runs every rebuild!
  final sortedItems = items
      .where((i) => i.isActive)
      .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

  // ❌ Creating objects - new animation controller every rebuild!
  final animController = AnimationController(vsync: this);

  return ListView.builder(
    controller: ScrollController(),  // ❌ New instance every rebuild!
    itemBuilder: (_, i) {
      return MyWidget(
        // ❌ Creating callbacks - new function instance!
        onTap: () => handleTap(sortedItems[i]),
      );
    },
  );
}
```

### ✅ Correct Patterns

```dart
class _MyWidgetState extends State<MyWidget> {
  // Create ONCE in state
  late final TextEditingController _textController;
  late final ScrollController _scrollController;
  late final AnimationController _animController;

  // Cache computed values
  List<Item> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _scrollController = ScrollController();
    _animController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _updateFilter() {
    // Compute ONCE when data changes, not every build
    _filteredItems = items
        .where((i) => i.isActive)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    setState(() {});
  }

  // Cache callbacks if needed
  void _handleTap(Item item) {
    // Handle tap
  }

  @override
  Widget build(BuildContext context) {
    // Build just reads and returns widgets
    return ListView.builder(
      controller: _scrollController,  // ✅ Reused
      itemCount: _filteredItems.length,
      itemBuilder: (_, i) {
        final item = _filteredItems[i];  // ✅ Pre-computed
        return MyWidget(
          item: item,
          onTap: () => _handleTap(item),  // ✅ Simple reference
        );
      },
    );
  }
}
```

### Using const Constructors

```dart
// ❌ Without const - new instance every rebuild
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Hello'),  // New Text widget created
      Icon(Icons.star),  // New Icon widget created
      SizedBox(height: 16),  // New SizedBox created
    ],
  );
}

// ✅ With const - same instance reused
Widget build(BuildContext context) {
  return Column(
    children: [
      const Text('Hello'),  // ✅ Compile-time constant
      const Icon(Icons.star),  // ✅ Compile-time constant
      const SizedBox(height: 16),  // ✅ Compile-time constant
    ],
  );
}

// Your own widgets can be const too!
class MyCard extends StatelessWidget {
  final String title;

  const MyCard({required this.title});  // ✅ const constructor

  @override
  Widget build(BuildContext context) {
    return Card(child: Text(title));
  }
}

// Usage
const MyCard(title: 'Static Title')  // ✅ Can use const
```

---

## 9. Memory Management & Disposal

### What Needs Disposal

| Type                    | Create      | Dispose   |
| ----------------------- | ----------- | --------- |
| `TextEditingController` | `initState` | `dispose` |
| `ScrollController`      | `initState` | `dispose` |
| `AnimationController`   | `initState` | `dispose` |
| `FocusNode`             | `initState` | `dispose` |
| `StreamSubscription`    | `initState` | `dispose` |
| `Timer`                 | `initState` | `dispose` |
| `TabController`         | `initState` | `dispose` |

### The Pattern

```dart
class _MyWidgetState extends State<MyWidget> {
  late final TextEditingController _controller;
  StreamSubscription? _subscription;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();

    _subscription = someStream.listen((data) {
      if (mounted) {  // Always check mounted!
        setState(() => _data = data);
      }
    });

    _timer = Timer.periodic(Duration(seconds: 5), (_) {
      if (mounted) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    // Cancel subscriptions FIRST (they might call setState)
    _subscription?.cancel();
    _timer?.cancel();

    // Then dispose controllers
    _controller.dispose();

    super.dispose();  // Always call super.dispose() LAST
  }
}
```

### The `mounted` Check

```dart
// ❌ BAD - Widget might be disposed during async gap
Future<void> _loadData() async {
  final data = await api.fetch();
  setState(() => _data = data);  // CRASH if widget disposed!
}

// ✅ GOOD - Check mounted before setState
Future<void> _loadData() async {
  final data = await api.fetch();

  if (mounted) {  // Widget still exists?
    setState(() => _data = data);
  }
}
```

### Memory Leak Detection

Add this to your debug builds:

```dart
void main() {
  // In debug mode, catch leaks
  assert(() {
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        onDetach: () {
          debugPrint('Check for memory leaks!');
        },
      ),
    );
    return true;
  }());

  runApp(MyApp());
}
```

---

## 10. Riverpod-Specific Patterns

### StateNotifier vs ChangeNotifier

```dart
// ChangeNotifier (classic) - Manual notification
class WorkOrderProvider with ChangeNotifier {
  List<WorkOrder> _orders = [];

  void addOrder(WorkOrder order) {
    _orders.add(order);
    notifyListeners();  // Must call manually!
  }
}

// StateNotifier (Riverpod 2.0) - Immutable state
class WorkOrderNotifier extends StateNotifier<List<WorkOrder>> {
  WorkOrderNotifier() : super([]);

  void addOrder(WorkOrder order) {
    state = [...state, order];  // State change auto-notifies
  }
}
```

### Non-Blocking Provider Initialization

```dart
// ❌ BAD - Blocking in constructor
class MyProvider with ChangeNotifier {
  MyProvider() {
    _init();  // Called during widget build!
  }

  Future<void> _init() async {
    await heavyOperation();  // Blocks UI!
  }
}

// ✅ GOOD - Explicit async initialization
class MyProvider with ChangeNotifier {
  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  Completer<void>? _initCompleter;

  Future<void> initialize() async {
    if (!_isInitializing) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer();
    notifyListeners();  // Show loading state

    Future.microtask(() async {
      await heavyOperation();
      _isInitializing = false;
      _initCompleter!.complete();
      notifyListeners();
    });

    return _initCompleter!.future;
  }
}

// In widget
@override
void initState() {
  super.initState();
  Future.microtask(() {
    ref.read(myProvider).initialize();
  });
}
```

### Reading vs Watching

```dart
@override
Widget build(BuildContext context) {
  // watch() - Rebuilds when value changes
  final items = ref.watch(itemsProvider);

  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (_, i) => Text(items[i].name),
  );
}

void _addItem() {
  // read() - One-time read, no rebuild subscription
  ref.read(itemsProvider.notifier).add(newItem);
}
```

---

## 11. Complete Do's and Don'ts

### ✅ DO

```dart
// ✅ DO use Future.microtask for async init
Future.microtask(() => _loadData());

// ✅ DO check mounted before setState
if (mounted) setState(() => _data = data);

// ✅ DO use const constructors
const Text('Hello')
const SizedBox(height: 16)
const MyWidget()

// ✅ DO cache computed values in state
List<Item> _sortedItems = [];
void _updateSort() {
  _sortedItems = items.toList()..sort();
  setState(() {});
}

// ✅ DO create controllers in initState
late final TextEditingController _controller;
@override
void initState() {
  super.initState();
  _controller = TextEditingController();
}

// ✅ DO dispose everything
@override
void dispose() {
  _controller.dispose();
  _subscription?.cancel();
  super.dispose();
}

// ✅ DO use compute for heavy parsing
final items = await compute(parseJson, jsonString);

// ✅ DO use AutomaticKeepAliveClientMixin for tabs
class _MyTabState extends State<MyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
}

// ✅ DO show skeleton during initial load
if (_isLoading && !_hasLoadedOnce) return SkeletonLoading();

// ✅ DO use hasLoadedOnce flag
bool _hasLoadedOnce = false;
```

### ❌ DON'T

```dart
// ❌ DON'T await in initState directly
@override
void initState() {
  await _loadData();  // WRONG!
}

// ❌ DON'T forget mounted check
Future<void> _load() async {
  final data = await api.fetch();
  setState(() => _data = data);  // CRASH if disposed!
}

// ❌ DON'T create objects in build
@override
Widget build(BuildContext context) {
  final controller = TextEditingController();  // WRONG!
  return TextField(controller: controller);
}

// ❌ DON'T do heavy computation in build
@override
Widget build(BuildContext context) {
  final sorted = items.toList()..sort();  // WRONG!
  return ListView(children: sorted.map(...));
}

// ❌ DON'T forget to dispose
// (No dispose method = MEMORY LEAK!)

// ❌ DON'T parse large JSON on main thread
final data = jsonDecode(hugeString);  // WRONG! Use compute()

// ❌ DON'T call setState after dispose
void _onData(data) {
  setState(() => _data = data);  // CRASH if widget disposed!
}

// ❌ DON'T block provider constructors
class MyProvider {
  MyProvider() {
    _heavyInit();  // WRONG! Blocks widget build.
  }
}
```

---

## 12. Performance Checklist

### Before Every PR

- [ ] **initState** uses `Future.microtask()` for async work
- [ ] **mounted** check before every `setState` after `await`
- [ ] **dispose()** cleans up all controllers, subscriptions, timers
- [ ] **build()** does no computation (just reads state)
- [ ] **const** constructors used for static widgets
- [ ] **compute()** used for parsing large JSON
- [ ] **Skeleton** loading for initial page loads
- [ ] **AutomaticKeepAliveClientMixin** for tabs that should persist
- [ ] No objects created in `build()`
- [ ] No callbacks defined inline in hot paths

### Quick Test

Run your app in profile mode and:

1. Navigate to a new page → Should not freeze
2. Switch tabs back and forth → Should be instant
3. Scroll a long list → Should be smooth 60fps
4. Parse large response → Should not stutter

```bash
flutter run --profile
```

---

## 13. Real-World Examples from This Project

### Example 1: Dashboard Tab (Before/After)

```dart
// ❌ BEFORE - Blocking
class _DailyReportTabState extends ConsumerState<DailyReportTab> {
  @override
  void initState() {
    super.initState();
    _loadData();  // Data loading started during build phase
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return CircularProgressIndicator();  // Basic spinner
    }
    return Content();
  }
}

// ✅ AFTER - Non-blocking with caching
class _DailyReportTabState extends ConsumerState<DailyReportTab>
    with AutomaticKeepAliveClientMixin {
  bool _hasLoadedOnce = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadData());  // Deferred
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // Required for mixin

    if (_isLoading && !_hasLoadedOnce) {
      return DashboardSkeletonLoading();  // Skeleton
    }
    // ... rest of build
  }
}
```

### Example 2: WorkOrderProvider (Before/After)

```dart
// ❌ BEFORE - Called from initState blocked UI
class WorkOrderProvider with ChangeNotifier {
  Future<void> initialize() async {
    await _powerSync.initialize(storage);  // 500ms+ blocking!
    await loadWorkOrdersByDate(today);
  }
}

// ✅ AFTER - Non-blocking with Completer
class WorkOrderProvider with ChangeNotifier {
  bool _isLoading = false;
  Completer<void>? _initCompleter;

  Future<void> initialize() async {
    if (!_isInitializing) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer();
    _isLoading = true;
    notifyListeners();  // UI shows skeleton

    Future.microtask(() async {
      await _initializeInternal();
    });

    return _initCompleter!.future;
  }

  Future<void> loadWorkOrdersByDate(DateTime date) async {
    await _ensureInitialized();  // Wait for init if needed
    // ... load data
  }
}
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│              FLUTTER PERFORMANCE QUICK REF                  │
├─────────────────────────────────────────────────────────────┤
│ INIT ASYNC WORK:    Future.microtask(() => _load())        │
│ CHECK DISPOSAL:     if (mounted) setState(...)             │
│ TAB CACHING:        with AutomaticKeepAliveClientMixin     │
│ HEAVY PARSING:      await compute(parseFunc, data)         │
│ FIRST LOAD:         if (loading && !hasLoadedOnce)         │
│ STATIC WIDGETS:     const Text('hello')                    │
│ DISPOSE ORDER:      cancel subs → dispose controllers      │
├─────────────────────────────────────────────────────────────┤
│ NEVER IN BUILD:     create controllers, heavy compute      │
│ NEVER IN INITSTATE: direct await                           │
│ NEVER FORGET:       dispose(), mounted check               │
└─────────────────────────────────────────────────────────────┘
```

---

This guide covers the patterns used in your project. Refer back to it whenever you're adding new screens or providers!
