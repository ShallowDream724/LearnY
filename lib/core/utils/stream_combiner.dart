import 'dart:async';

Stream<R> combineLatest2<A, B, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  R Function(A valueA, B valueB) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;

  void emitIfReady() {
    if (!hasA || !hasB || controller.isClosed) {
      return;
    }
    controller.add(combine(latestA as A, latestB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emitIfReady();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emitIfReady();
      }, onError: controller.addError);
    },
    onPause: () {
      subA?.pause();
      subB?.pause();
    },
    onResume: () {
      subA?.resume();
      subB?.resume();
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );

  return controller.stream;
}

Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  R Function(A valueA, B valueB, C valueC) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  A? latestA;
  B? latestB;
  C? latestC;
  var hasA = false;
  var hasB = false;
  var hasC = false;

  void emitIfReady() {
    if (!hasA || !hasB || !hasC || controller.isClosed) {
      return;
    }
    controller.add(combine(latestA as A, latestB as B, latestC as C));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emitIfReady();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emitIfReady();
      }, onError: controller.addError);
      subC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emitIfReady();
      }, onError: controller.addError);
    },
    onPause: () {
      subA?.pause();
      subB?.pause();
      subC?.pause();
    },
    onResume: () {
      subA?.resume();
      subB?.resume();
      subC?.resume();
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
    },
  );

  return controller.stream;
}

Stream<R> combineLatest4<A, B, C, D, R>(
  Stream<A> streamA,
  Stream<B> streamB,
  Stream<C> streamC,
  Stream<D> streamD,
  R Function(A valueA, B valueB, C valueC, D valueD) combine,
) {
  late final StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  StreamSubscription<C>? subC;
  StreamSubscription<D>? subD;
  A? latestA;
  B? latestB;
  C? latestC;
  D? latestD;
  var hasA = false;
  var hasB = false;
  var hasC = false;
  var hasD = false;

  void emitIfReady() {
    if (!hasA || !hasB || !hasC || !hasD || controller.isClosed) {
      return;
    }
    controller.add(
      combine(latestA as A, latestB as B, latestC as C, latestD as D),
    );
  }

  controller = StreamController<R>(
    onListen: () {
      subA = streamA.listen((value) {
        latestA = value;
        hasA = true;
        emitIfReady();
      }, onError: controller.addError);
      subB = streamB.listen((value) {
        latestB = value;
        hasB = true;
        emitIfReady();
      }, onError: controller.addError);
      subC = streamC.listen((value) {
        latestC = value;
        hasC = true;
        emitIfReady();
      }, onError: controller.addError);
      subD = streamD.listen((value) {
        latestD = value;
        hasD = true;
        emitIfReady();
      }, onError: controller.addError);
    },
    onPause: () {
      subA?.pause();
      subB?.pause();
      subC?.pause();
      subD?.pause();
    },
    onResume: () {
      subA?.resume();
      subB?.resume();
      subC?.resume();
      subD?.resume();
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
      await subC?.cancel();
      await subD?.cancel();
    },
  );

  return controller.stream;
}
