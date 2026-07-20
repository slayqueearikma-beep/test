import 'app_strings.dart';

class AppStringsEn extends AppStrings {
  @override
  String get appName => 'MarGem';
  @override
  String get appTagline => 'Discover Morocco\'s Hidden Gems';
  @override
  String get selectLanguage => 'Choose your language';
  @override
  String get selectLanguageSubtitle =>
      'Select the language you prefer. You can change it anytime in Settings.';
  @override
  String get english => 'English';
  @override
  String get french => 'Français';
  @override
  String get arabic => 'العربية';
  @override
  String get next => 'Next';
  @override
  String get back => 'Back';
  @override
  String get continueLabel => 'Continue';
  @override
  String get skip => 'Skip';
  @override
  String get login => 'Login';
  @override
  String get logOut => 'Log out';
  @override
  String get cancel => 'Cancel';
  @override
  String get deleteAccount => 'Delete account';
  @override
  String get deleteAccountConfirm =>
      'This permanently deletes your account and shop data. Enter your password to confirm.';
  @override
  String get getStarted => 'Get Started';
  @override
  String get createAccount => 'Create an account';
  @override
  String get seeAll => 'See all';
  @override
  String get soon => 'Soon';
  @override
  String get remove => 'Remove';
  @override
  String get upload => 'Upload';
  @override
  String get settings => 'Settings';
  @override
  String get language => 'Language';
  @override
  String get discoverTitle => 'Discover Local Businesses';
  @override
  String get discoverSubtitle =>
      'Find trusted shops, products, and services across Morocco — all in one place.';
  @override
  String get exploreMapTitle => 'Explore on the Map';
  @override
  String get exploreMapSubtitle =>
      'Browse nearby stores, filter by category, and get directions instantly.';
  @override
  String get trustedReviewsTitle => 'Trusted Reviews';
  @override
  String get trustedReviewsSubtitle =>
      'Read ratings from real buyers and discover the most trusted businesses in your city.';
  @override
  String get chooseAccountType => 'Choose your account type';
  @override
  String get chooseAccountTypeSubtitle =>
      'Select how you want to use MarGem. You can always update your profile later.';
  @override
  String get buyer => 'Buyer';
  @override
  String get buyerSubtitle =>
      'Discover and support local businesses in your city.';
  @override
  String get seller => 'Seller';
  @override
  String get sellerSubtitle =>
      'Create your online presence and reach more customers.';
  @override
  String get buyerBullet1 => 'Discover nearby stores';
  @override
  String get buyerBullet2 => 'Browse products';
  @override
  String get buyerBullet3 => 'Read reviews';
  @override
  String get buyerBullet4 => 'Find businesses on the map';
  @override
  String get sellerBullet1 => 'Create your business profile';
  @override
  String get sellerBullet2 => 'Upload products and services';
  @override
  String get sellerBullet3 => 'Manage customers';
  @override
  String get sellerBullet4 => 'Grow your visibility';
  @override
  String get welcomeBack => 'Welcome back';
  @override
  String get loginSubtitle =>
      'Log in to continue discovering trusted local businesses.';
  @override
  String get logIn => 'Log in';
  @override
  String get enterEmailPassword => 'Please enter your email and password.';
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get fullName => 'Full name';
  @override
  String get createBuyerAccount => 'Create your buyer account';
  @override
  String get createBuyerSubtitle =>
      'Start discovering trusted local businesses in minutes.';
  @override
  String get profilePictureOptional => 'Profile picture (optional)';
  @override
  String get passwordHint => 'Min 8 chars, upper, lower, number';
  @override
  String get city => 'City';
  @override
  String get fillRequiredFields =>
      'Please fill all required fields (password min 6 characters).';
  @override
  String get navHome => 'Home';
  @override
  String get navSearch => 'Search';
  @override
  String get navMap => 'Map';
  @override
  String get navProfile => 'Profile';
  @override
  String goodMorning(String name) =>
      name.isEmpty ? 'Good morning' : 'Good morning, $name';
  @override
  String get searchHint => 'Search shops, products, services…';
  @override
  String get categories => 'Categories';
  @override
  String get exploreOnMap => 'Explore on the map';
  @override
  String exploreOnMapSubtitle(String city) => 'View all businesses in $city';
  @override
  String get featuredBusinesses => 'Featured businesses';
  @override
  String get nearbyBusinesses => 'Nearby businesses';
  @override
  String get topRatedSellers => 'Top-rated sellers';
  @override
  String get noBusinessesInCity => 'No businesses found in this city yet.';
  @override
  String get couldNotLoadBusinesses => 'Could not load businesses';
  @override
  String get serverUnreachable =>
      'Cannot reach the server. Start the backend and, on a physical phone, set API_BASE_URL to your PC IP (e.g. http://192.168.1.10:8000).';
  @override
  String get somethingWentWrong => 'Something went wrong';
  @override
  String get search => 'Search';
  @override
  String get businessKeyword => 'Business name or keyword';
  @override
  String get noBusinessesFound => 'No businesses found';
  @override
  String warningZones(int count) => '$count warning zone(s)';
  @override
  String get yourProfile => 'Your profile';
  @override
  String get darkMode => 'Dark mode';
  @override
  String get buyerLabel => 'Buyer';
  @override
  String get sellerDashboard => 'Seller Dashboard';
  @override
  String get yourBusiness => 'Your Business';
  @override
  String welcomeSeller(String name) => 'Welcome, $name 👋';
  @override
  String get manageStoreSubtitle =>
      'Manage your store, products, and customer reviews.';
  @override
  String get profileViews => 'Profile views';
  @override
  String get products => 'Products';
  @override
  String get reviews => 'Reviews';
  @override
  String get inquiries => 'Inquiries';
  @override
  String get manage => 'Manage';
  @override
  String get productManagement => 'Product management';
  @override
  String get productManagementSub =>
      'Add, edit, or remove products and services';
  @override
  String get reviewsSub => 'View and respond to customer reviews';
  @override
  String get profileManagement => 'Profile management';
  @override
  String get profileManagementSub => 'Update business info, hours, and photos';
  @override
  String get orders => 'Orders';
  @override
  String get ordersSub => 'Track and manage customer orders';
  @override
  String get messages => 'Messages';
  @override
  String get messagesSub => 'Chat with buyers directly';
  @override
  String get profileViewsTrend => '+12% this week';
  @override
  String get previewStorefront => 'Preview storefront';
  @override
  String get previewStorefrontSub => 'See your public store as buyers see it';
  @override
  String get accountSecurity => 'Account & security';
  @override
  String get accountSecuritySub => 'Password, theme, and account deletion';
  @override
  String get notifications => 'Notifications';
  @override
  String get storeInactiveHint =>
      'Your store is hidden from buyers. Enable it in profile settings.';
  @override
  String availableCount(int count) => '$count available';
  @override
  String achievementStars(int count) => '$count achievement stars';
  @override
  String get addProduct => 'Add product';
  @override
  String get editProduct => 'Edit product';
  @override
  String get saveChanges => 'Save changes';
  @override
  String get deleteProduct => 'Delete product';
  @override
  String get deleteProductConfirm =>
      'Delete this product permanently? This cannot be undone.';
  @override
  String get markUnavailable => 'Mark unavailable';
  @override
  String get markAvailable => 'Mark available';
  @override
  String get available => 'Available';
  @override
  String get unavailable => 'Unavailable';
  @override
  String get noProductsYet =>
      'No products yet. Add your first product to appear in search.';
  @override
  String get productSaved => 'Product saved';
  @override
  String get productDeleted => 'Product deleted';
  @override
  String get profileSaved => 'Profile updated';
  @override
  String get storeVisible => 'Store is visible to buyers';
  @override
  String get storeHidden => 'Store is hidden from buyers';
  @override
  String get changePassword => 'Change password';
  @override
  String get currentPassword => 'Current password';
  @override
  String get newPassword => 'New password';
  @override
  String get passwordChanged =>
      'Password updated. Please sign in again on other devices.';
  @override
  String get recentReviews => 'Recent reviews';
  @override
  String get noNotifications => 'No new notifications';
  @override
  String get notificationsSubtitle =>
      'Orders, messages, premium, and account updates appear here.';
  @override
  String get appearance => 'Appearance';
  @override
  String get systemTheme => 'System';
  @override
  String get lightTheme => 'Light';
  @override
  String get darkTheme => 'Dark';
  @override
  String get sellerStep1Title => 'Business account';
  @override
  String get sellerStep1Subtitle =>
      'Step 1 of 5 — Tell us about you and your business.';
  @override
  String get businessName => 'Business name';
  @override
  String get ownerName => 'Owner name';
  @override
  String get sellerStep2Title => 'Location & contact';
  @override
  String get sellerStep2Subtitle =>
      'Step 2 of 5 — Help buyers find your physical store.';
  @override
  String get businessCategory => 'Business category';
  @override
  String get fullAddress => 'Full address';
  @override
  String get phoneNumber => 'Phone number';
  @override
  String get storeLocation => 'Store location';
  @override
  String get tapMapToSetPin => 'Tap the map to set your store pin.';
  @override
  String get sellerStep3Title => 'Business profile';
  @override
  String get sellerStep3Subtitle => 'Step 3 of 5 — Make your store stand out.';
  @override
  String get businessDescription => 'Business description';
  @override
  String get businessLogo => 'Business logo';
  @override
  String get coverPhoto => 'Cover photo';
  @override
  String get openingHours => 'Opening hours';
  @override
  String get opens => 'Opens';
  @override
  String get closes => 'Closes';
  @override
  String get sellerStep4Title => 'First products & services';
  @override
  String get sellerStep4Subtitle =>
      'Step 4 of 5 — Add at least one item to your catalog.';
  @override
  String get productImage => 'Product image';
  @override
  String get name => 'Name';
  @override
  String get description => 'Description';
  @override
  String get priceOptional => 'Price (MAD, optional)';
  @override
  String get addAnotherItem => 'Add another item';
  @override
  String get sellerStep5Title => 'Review & submit';
  @override
  String get sellerStep5Subtitle =>
      'Step 5 of 5 — Confirm your information before creating your account.';
  @override
  String get submitCreateAccount => 'Submit & create account';
  @override
  String get completeRequiredStep =>
      'Please complete all required fields before continuing.';
  @override
  String sellerVisibilityNote(String city) =>
      'Your business profile will be visible to buyers in $city once your account is created.';
  @override
  String get reviewBusiness => 'Business';
  @override
  String get reviewOwner => 'Owner';
  @override
  String get reviewCategory => 'Category';
  @override
  String get reviewCity => 'City';
  @override
  String get reviewAddress => 'Address';
  @override
  String get reviewPhone => 'Phone';
  @override
  String get reviewProducts => 'Products';
  @override
  String reviewsCount(int count) => '$count reviews';
  @override
  String get directions => 'Directions';
  @override
  String get review => 'Review';
  @override
  String get services => 'Services';
  @override
  String get noProductsListed => 'No products listed yet.';
  @override
  String get noServicesListed => 'No services listed yet.';
  @override
  String get noReviewsYet => 'No reviews yet.';
  @override
  String get submitReview => 'Submit review';
  @override
  String get shareExperience => 'Share your experience (optional)';
  @override
  String get noPhone => 'No phone';
  @override
  String get noDescription => 'No description provided.';
  @override
  String get categoryFood => 'Food';
  @override
  String get categoryClothing => 'Clothing';
  @override
  String get categoryElectronics => 'Electronics';
  @override
  String get categoryBeauty => 'Beauty';
  @override
  String get categoryServices => 'Services';
  @override
  String get categoryHomeGarden => 'Home & Garden';
  @override
  String get categoryHealth => 'Health';
  @override
  String get categorySports => 'Sports';
  @override
  String get tapToUpload => 'Tap to upload';
  @override
  String get yourName => 'Your name';
  @override
  String get emailHint => 'you@example.com';
  @override
  String get businessNameHint => 'e.g. Hana Chicken';
  @override
  String get ownerNameHint => 'Your full name';
  @override
  String get addressHint => 'Street, neighborhood';
  @override
  String get phoneHint => '+212 6XX XXX XXX';
  @override
  String get descriptionHint => 'Tell buyers what makes your business special…';
  @override
  String get productNameHint => 'Product or service name';
  @override
  String get productDescriptionHint => 'Short description';
  @override
  String get priceHint => 'e.g. 49.99';
  @override
  String get returningUser => 'Returning User';
  @override
  String get sellerDefault => 'Seller';
  @override
  String itemsCount(int count) => '$count item(s)';
  @override
  String get guestContinue => 'Continue as guest';
  @override
  String get guestMode => 'Guest mode';
  @override
  String get guestModeSubtitle =>
      'Browse freely and keep a local cart. Sign in to checkout, save wishlist items, and view orders.';
  @override
  String get cart => 'Cart';
  @override
  String get checkout => 'Checkout';
  @override
  String get wishlist => 'Wishlist';
  @override
  String get premium => 'Premium';
  @override
  String get guestCartSignInHint =>
      'Your cart is saved on this device. Sign in to checkout and sync it to your account.';
  @override
  String get signInToCheckout => 'Sign in to checkout';
  @override
  String get subtotal => 'Subtotal';
  @override
  String get emptyCart => 'Your cart is empty';
  @override
  String get emptyCartSubtitle =>
      'Add products from local sellers and they will appear here.';
  @override
  String get browseProducts => 'Browse products';
  @override
  String get addToCart => 'Add to cart';
  @override
  String get addToWishlist => 'Add to wishlist';
  @override
  String get addedToCart => 'Added to cart';
  @override
  String get addedToWishlist => 'Added to wishlist';
  @override
  String get priceOnRequest => 'Price on request';
  @override
  String get orderSummary => 'Order summary';
  @override
  String get deliveryDetails => 'Delivery details';
  @override
  String get recipientName => 'Recipient name';
  @override
  String get requiredField => 'Required';
  @override
  String get deliveryAddress => 'Delivery address';
  @override
  String get orderNoteOptional => 'Order note (optional)';
  @override
  String get placingOrder => 'Placing order...';
  @override
  String get placeOrder => 'Place order';
  @override
  String get noOrdersYet => 'No orders yet';
  @override
  String get noOrdersYetSubtitle =>
      'Your purchases from local sellers will appear here.';
  @override
  String orderNumber(String id) => 'Order #$id';
  @override
  String get orderStatusPending => 'Pending';
  @override
  String get orderStatusAccepted => 'Accepted';
  @override
  String get orderStatusReady => 'Ready';
  @override
  String get orderStatusCompleted => 'Completed';
  @override
  String get orderStatusCancelled => 'Cancelled';
  @override
  String get orderStatusRejected => 'Rejected';
  @override
  String get orderDetails => 'Order details';
  @override
  String get deliveryFee => 'Delivery fee';
  @override
  String get total => 'Total';
  @override
  String get paymentMethod => 'Payment method';
  @override
  String get items => 'Items';
  @override
  String get orderNote => 'Order note';
  @override
  String get sellerNote => 'Seller note';
  @override
  String get cancelOrder => 'Cancel order';
  @override
  String get cancelOrderConfirm =>
      'Cancel this order? The seller will be notified.';
  @override
  String get emptyWishlist => 'Your wishlist is empty';
  @override
  String get emptyWishlistSubtitle =>
      'Save products you like and come back to them later.';
  @override
  String get premiumActivated => 'Premium activated';
  @override
  String get noPremiumPlans => 'No premium plans are available right now.';
  @override
  String get premiumTitle => 'Grow with MarGem Premium';
  @override
  String get premiumSubtitle =>
      'Unlock stronger visibility, seller tools, and commerce features.';
  @override
  String activePlan(String name) => 'Active plan: $name';
  @override
  String get signInToSubscribe => 'Sign in to subscribe';
  @override
  String get days => 'days';
  @override
  String get currentPlan => 'Current plan';
  @override
  String get subscribe => 'Subscribe';
  @override
  String get noSellerOrders => 'No customer orders yet';
  @override
  String get noSellerOrdersSubtitle =>
      'New orders placed by buyers will appear here.';
  @override
  String get acceptOrder => 'Accept';
  @override
  String get rejectOrder => 'Reject';
  @override
  String get sellerNoteOptional => 'Seller note (optional)';
  @override
  String get confirm => 'Confirm';
  @override
  String get markReady => 'Mark ready';
  @override
  String get completeOrder => 'Complete';
  @override
  String get forgotPassword => 'Forgot password?';
  @override
  String get resetPassword => 'Reset password';
  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we will send a secure reset link if an account exists.';
  @override
  String get resetPasswordSubtitle =>
      'Paste the reset token from your email and choose a new password.';
  @override
  String get emailRequired => 'Email is required.';
  @override
  String get resetPasswordValidation =>
      'Enter the reset token and a password with at least 8 characters.';
  @override
  String get sendResetLink => 'Send reset link';
  @override
  String get resetLinkSent =>
      'If an account exists, a reset link has been sent.';
  @override
  String get resetToken => 'Reset token';
  @override
  String get passwordResetComplete =>
      'Password reset complete. You can now log in.';
  @override
  String get revenue => 'Revenue';
  @override
  String pendingOrders(int count) => '$count pending';
  @override
  String completedOrders(int count) => '$count completed';
  @override
  String get analytics => 'Analytics';
  @override
  String get analyticsSub => 'View orders, revenue, and profile performance';
  @override
  String analyticsSummary(String revenue, String average) =>
      '$revenue MAD revenue · $average MAD avg order';
  @override
  String get premiumActiveSub => 'Your premium plan is active';
  @override
  String get premiumUpgradeSub => 'Upgrade visibility and selling tools';
  @override
  String get loading => 'Loading...';
  @override
  String get pending => 'Pending';
  @override
  String get completed => 'Completed';
  @override
  String get averageOrder => 'Average order';
  @override
  String get verification => 'Verification';
  @override
  String get markAllRead => 'Mark all read';

  @override
  String categoryLabel(String key) {
    switch (key) {
      case 'Food':
        return categoryFood;
      case 'Clothing':
        return categoryClothing;
      case 'Electronics':
        return categoryElectronics;
      case 'Beauty':
        return categoryBeauty;
      case 'Services':
        return categoryServices;
      case 'Home & Garden':
        return categoryHomeGarden;
      case 'Health':
        return categoryHealth;
      case 'Sports':
        return categorySports;
      default:
        return key;
    }
  }

  @override
  String dayLabel(String key) {
    const days = {
      'Mon': 'Mon',
      'Tue': 'Tue',
      'Wed': 'Wed',
      'Thu': 'Thu',
      'Fri': 'Fri',
      'Sat': 'Sat',
      'Sun': 'Sun'
    };
    return days[key] ?? key;
  }
}
