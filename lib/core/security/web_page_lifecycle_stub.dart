class WebPageLifecycle {
  const WebPageLifecycle();

  void listen(void Function() onHidden) {}

  void cancel() {}
}

WebPageLifecycle createWebPageLifecycle() => const WebPageLifecycle();
