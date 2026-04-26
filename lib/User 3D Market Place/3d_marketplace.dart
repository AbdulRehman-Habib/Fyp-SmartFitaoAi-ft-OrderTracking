import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../Order-Tracking-System/firebase_pages.dart';
import '../Order-Tracking-System/services/app_backend.dart';
import 'product_viewer.dart';
import 'profile.dart';
import 'reel.dart';
import 'loginforgetsign/auth_flow.dart';
import 'chat.dart';
import 'loginforgetsign/login_form.dart';
import 'database/debug_orders.dart';
import 'database/connectivity_check.dart';
import 'database/order_tracking_service.dart';
import 'database/firebase_service.dart';

class MarketPlace3D extends StatefulWidget {
  const MarketPlace3D({super.key});

  @override
  _MarketPlace3DState createState() => _MarketPlace3DState();
}

class _MarketPlace3DState extends State<MarketPlace3D> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _currentBanner = 0;
  Map<String, int> _trackingCounts = {};
  late PageController _bannerController;
  Timer? _bannerTimer;
  late AnimationController _animationController;
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  final List<String> categories = ['All', 'Shalwar Kameez', 'Kurtaz Pajama', 'Fabric'];

  final List<Map<String, dynamic>> banners = [
    {
      'image': 'assets/banner 1.png',
      'title': 'Shalwar Kameez',
      'subtitle': 'Premium Collection',
      'offer': 'FLAT 30% OFF',
      'code': 'ETHNIC30',
    },
    {
      'image': 'assets/banner 2.png',
      'title': 'Kurtaz Pajama',
      'subtitle': 'Modern Fits',
      'offer': 'New Arrivals',
      'code': 'KURTA20',
    },
    {
      'image': 'assets/banner 33.png',
      'title': 'Premium Fabric',
      'subtitle': 'Unstitched Luxury',
      'offer': 'For Your Custom Fit',
      'code': 'FABRIC10',
    },
  ];

  /// Demo list used only by the debug “Upload All Products” menu action.
  final List<Map<String, dynamic>> _demoProductsForUpload = [
    {
      'id': 1,
      'title': 'Classic White Shalwar Kameez',
      'price': 5490,
      'originalPrice': 6990,
      'category': 'Shalwar Kameez',
      'modelPath': 'models/product1/sample1.gltf',
      'rating': 4.8,
      'reviews': 0,
    },
    {
      'id': 2,
      'title': 'Boski Shalwar Kameez – Ivory',
      'price': 6450,
      'originalPrice': 7990,
      'category': 'Shalwar Kameez',
      'modelPath': 'models/product2/sample1.gltf',
      'rating': 4.7,
      'reviews': 0,
    },
    {
      'id': 3,
      'title': 'Wash & Wear Kurta Pajama – Grey',
      'price': 4890,
      'originalPrice': 6290,
      'category': 'Kurtaz Pajama',
      'modelPath': 'models/product3/sample5.gltf',
      'rating': 4.6,
      'reviews': 0,
    },
    {
      'id': 4,
      'title': 'Premium Unstitched Fabric – 3 Piece',
      'price': 7250,
      'originalPrice': 8990,
      'category': 'Fabric',
      'modelPath': 'models/product4/sample8.gltf',
      'rating': 4.9,
      'reviews': 0,
    },
    {
      'id': 5,
      'title': 'Signature Kurta – Charcoal',
      'price': 4850,
      'originalPrice': 5990,
      'category': 'Kurtaz Pajama',
      'modelPath': 'models/product5/sample4.gltf',
      'rating': 4.5,
      'reviews': 0,
    },
  ];

  final AppBackend _backend = AppBackend.instance;
  StreamSubscription<List<ProductModel>>? _catalogSub;
  StreamSubscription<User?>? _authProfileSub;
  List<Map<String, dynamic>> _catalogProducts = [];
  bool _catalogLoading = true;
  String? _catalogError;
  AppUserProfile? _marketplaceUserProfile;

  @override
  void initState() {
    super.initState();
    _catalogSub = _backend.streamAllProducts().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _catalogProducts = list.map((p) => _backend.marketplaceProductMap(p)).toList();
          _catalogLoading = false;
          _catalogError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _catalogLoading = false;
          _catalogError = e.toString();
        });
      },
    );
    _bannerController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });

    _startBannerAutoScroll();
    _loadTrackingCounts();

    _authProfileSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;
      if (user == null) {
        setState(() => _marketplaceUserProfile = null);
        return;
      }
      try {
        final p = await _backend.getUserProfile(user.uid);
        if (mounted) setState(() => _marketplaceUserProfile = p);
      } catch (_) {
        if (mounted) setState(() => _marketplaceUserProfile = null);
      }
    });
  }

  Future<void> _loadTrackingCounts() async {
    final counts = await OrderTrackingService.getAllCounts();
    setState(() {
      _trackingCounts = counts;
    });
  }

  Future<void> _uploadAllProducts() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Uploading products to Firebase...')),
    );
    try {
      final count = await FirebaseService.uploadProductsFromList(_demoProductsForUpload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully uploaded $count products!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(Duration(seconds: 4), (timer) {
      if (mounted && _bannerController.hasClients) {
        setState(() {
          _currentBanner = (_currentBanner + 1) % banners.length;
        });
        _bannerController.animateToPage(
          _currentBanner,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _catalogSub?.cancel();
    _authProfileSub?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _catalogProducts.where((product) {
      final matchesCategory = _selectedCategory == 'All' || product['category'] == _selectedCategory;
      final matchesSearch = product['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;



    final scrollProgress = (_scrollOffset / 400).clamp(0.0, 1.0);


    Color bgColor1, bgColor2, bgColor3;

    if (scrollProgress < 0.5) {

      final t = scrollProgress * 2;
      bgColor1 = Color.lerp(Color(0xFF059669), Colors.white, t)!;
      bgColor2 = Color.lerp(Color(0xFF10b981), Colors.white, t)!;
      bgColor3 = Color.lerp(Color(0xFF059669), Colors.white, t)!;
    } else {

      final t = (scrollProgress - 0.5) * 2;
      bgColor1 = Color.lerp(Colors.white, Color(0xFF059669), t)!;
      bgColor2 = Color.lerp(Colors.white, Color(0xFF10b981), t)!;
      bgColor3 = Color.lerp(Colors.white, Color(0xFF059669), t)!;
    }

    return Scaffold(
      floatingActionButton: null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgColor1,
              bgColor2,
              bgColor3,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [

                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfileScreen()),
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: AssetImage('assets/profile.jpg'),
                              ),
                              SizedBox(width: 10),
                              Text(
                                _marketplaceUserProfile?.name ?? 'Sign in',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Debug menu: open debug orders or connectivity checker
                        Row(
                          children: [
                            PopupMenuButton<String>(
                              icon: Icon(Icons.developer_mode, color: Colors.black),
                              onSelected: (value) {
                                if (value == 'debug_orders') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => DebugOrdersPage()),
                                  );
                                } else if (value == 'connectivity') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => FirebaseConnectivityCheckPage()),
                                  );
                                } else if (value == 'upload_products') {
                                  _uploadAllProducts();
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(value: 'debug_orders', child: Text('Debug Orders')),
                                PopupMenuItem(value: 'connectivity', child: Text('Firebase Check')),
                                PopupMenuDivider(),
                                PopupMenuItem(value: 'upload_products', child: Text('Upload All Products')),
                              ],
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (FirebaseAuth.instance.currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sign in as a user to track orders')),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(builder: (_) => const UserOrdersPageFirebase()),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Color(0xFF059669).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(0xFF059669).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, color: Color(0xFF059669), size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Track orders',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF059669), fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        if (screenW > 700) ...[
                          Text(
                            '3D Marketplace',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Discover custom tailored products',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                          SizedBox(height: 16),
                        ],

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Icon(Icons.search, color: Colors.grey[400], size: 20),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) => setState(() => _searchQuery = value),
                                    decoration: InputDecoration(
                                      hintText: 'Search products...',
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF059669),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),


            SliverToBoxAdapter(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.35,
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PageView.builder(
                  controller: _bannerController,
                  onPageChanged: (index) {
                    setState(() => _currentBanner = index);
                    _bannerTimer?.cancel();
                    _startBannerAutoScroll();
                  },
                  itemCount: banners.length,
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              banner['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF059669),
                                        Color(0xFF047857),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF059669),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      banner['offer'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    banner['title'],
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    banner['subtitle'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),


            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  banners.length,
                  (index) => Container(
                    width: _currentBanner == index ? 24 : 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentBanner == index
                          ? Color(0xFF059669)
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),


            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    SizedBox(height: 0),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      physics: BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          {'icon': Icons.inventory_2_outlined, 'label': 'Seller to\nTailor', 'key': 'seller_to_tailor'},
                          {'icon': Icons.local_shipping_outlined, 'label': 'Tailor\nDelivered', 'key': 'tailor_delivered'},
                          {'icon': Icons.check_circle_outline, 'label': 'Tailor Ready', 'key': 'tailor_ready'},
                          {'icon': Icons.outbound_outlined, 'label': 'Tailor to\nShip', 'key': 'tailor_to_ship'},
                          {'icon': Icons.markunread_mailbox_outlined, 'label': 'Delivered', 'key': 'delivered'},
                          {'icon': Icons.cancel_presentation, 'label': 'Cancelled', 'key': 'cancelled'},
                        ].map((item) {
                          final count = _trackingCounts[item['key']] ?? 0;
                          return GestureDetector(
                            onTap: () {
                              String title = (item['label'] as String).replaceAll('\n', ' ');
                              _showOrderDetails(context, title);
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 20.0),
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(color: Color(0xFF059669).withOpacity(0.5), width: 1.5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(item['icon'] as IconData, color: Color(0xFF059669), size: 32),
                                      ),
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF5D4037),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: Text(
                                            count.toString(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    item['label'] as String,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF5D4037),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),


            SliverToBoxAdapter(
              child: Container(
                height: 50,
                margin: EdgeInsets.symmetric(vertical: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = category),
                      child: Container(
                        margin: EdgeInsets.only(right: 8),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Color(0xFF059669) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? Color(0xFF059669) : Colors.grey[200]!,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),


            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Most Popular Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: TextStyle(color: Color(0xFF059669)),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, color: Color(0xFF059669), size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),


            if (_catalogLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF059669))),
              )
            else if (_catalogError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load products: $_catalogError',
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
              )
            else if (_filteredProducts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No products from registered sellers yet. Sellers can add listings from Seller → Products (+).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700], fontSize: 15),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: screenW > 700 ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.65,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final product = _filteredProducts[i];
                      void openProduct() {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => ProductViewerScreen(product: product),
                          ),
                        );
                      }

                      final imageUrl = product['imageUrl'] as String?;
                      final modelPath = product['modelPath'] as String?;
                      final orig = product['originalPrice'];
                      final outOfStock = product['outOfStock'] == true;
                      final discRaw = product['discountPercent'];
                      final discPct = discRaw is num ? discRaw.toDouble() : double.tryParse(discRaw?.toString() ?? '') ?? 0.0;
                      final hasDiscount = discPct > 0;
                      final showDiscountTag = !outOfStock && hasDiscount;

                      return GestureDetector(
                        onTap: openProduct,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        color: Colors.black,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                        child: imageUrl != null && imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity,
                                                errorBuilder: (_, __, ___) => Center(
                                                  child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
                                                ),
                                              )
                                            : (modelPath != null && modelPath.isNotEmpty)
                                                ? ModelViewer(
                                                    src: kIsWeb ? '${Uri.base.origin}/$modelPath' : modelPath,
                                                    alt: product['title']?.toString() ?? '3D body',
                                                    autoRotate: true,
                                                    cameraControls: true,
                                                    ar: false,
                                                    backgroundColor: Colors.transparent,
                                                  )
                                                : Center(
                                                    child: Icon(Icons.storefront, color: Colors.white38, size: 40),
                                                  ),
                                      ),
                                    ),
                                    if (showDiscountTag)
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${discPct.round()}% OFF',
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    if (outOfStock)
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Out of Stock',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['title']?.toString() ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            product['category']?.toString() ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    'Rs ${product['price']}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 14,
                                                      color: Color(0xFF059669),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (orig != null && orig != 0) ...[
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Rs $orig',
                                                    style: TextStyle(
                                                      decoration: TextDecoration.lineThrough,
                                                      color: Colors.grey[400],
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: outOfStock ? null : openProduct,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: outOfStock ? Colors.grey : Color(0xFF059669),
                                              disabledBackgroundColor: Colors.grey.shade400,
                                              minimumSize: Size(96, 32),
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              outOfStock ? 'Unavailable' : 'Buy Now',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _filteredProducts.length,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginFormScreen(
                        userType: UserType.tailor,
                        onSuccess: () {}, 
                        onRegister: () {},
                        onForgotPassword: (_) {},
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF171717), Color(0xFF2d2d2d)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Find Your Perfect Tailor",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Login as a tailor to manage orders and measurements.",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_forward, color: Color(0xFF171717)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginFormScreen(
                        userType: UserType.seller,
                        onSuccess: () {}, 
                        onRegister: () {},
                        onForgotPassword: (_) {},
                        onBack: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF134E4A)], // Teal/Dark Teal for distinction
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Become a Seller",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Login as a seller to manage products and sales.",
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.store, color: Color(0xFF134E4A)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 80)), 
          ],
        ),
      ),
      ),
      ReelScreen(),
      ChatScreen(),
      ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Color(0xFF059669),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_collection_outlined),
              label: 'Reel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
  void _showOrderDetails(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$title Orders",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
              SizedBox(height: 15),
              _buildOrderListItem("Custom Suit - Order #4821", title, "PKR 4,500", Icons.shopping_bag),
              SizedBox(height: 15),
              _buildOrderListItem("Kurtas - Order #4825", title, "PKR 2,200", Icons.checkroom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderListItem(String orderName, String status, String price, IconData icon) {
     return Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Color(0xFF059669).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Color(0xFF059669).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color(0xFF5D4037).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Color(0xFF5D4037), size: 30),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(orderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 5),
                          Text("Status: $status", style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w500)),
                          SizedBox(height: 5),
                          Text(price, style: TextStyle(color: Color(0xFF5D4037), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              );
  }
}