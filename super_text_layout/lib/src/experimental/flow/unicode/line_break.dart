part of '../flow.dart';

/// Default Unicode 16.0.0 UAX #14 opportunities, in UTF-16 offsets.
/// SA uses the default AL/CM resolution; dictionary segmentation is separate.
/// Rule implementation adapted from uniseg 0.10.1 (Masaaki Shibata, MIT).
/// See tool/unicode/UNISEG-LICENSE.txt and UNICODE-LICENSE.txt.
class UnicodeLineBreaks {
  static const unicodeVersion = '16.0.0';

  static List<UnicodeLineBreak> compute(String text) {
    final runes = text.runes.toList();
    if (runes.isEmpty) {
      return const [UnicodeLineBreak(0)];
    }
    final props = runes.map(_unicodeBreakProperty).toList();
    final classes = props.map((p) => _Lb.values[p & 63]).toList();
    final starts = <int>[0];
    for (final rune in runes) {
      starts.add(starts.last + (rune > 0xffff ? 2 : 1));
    }
    const al = _Lb.al,
        hl = _Lb.hl,
        nu = _Lb.nu,
        sp = _Lb.sp,
        zw = _Lb.zw,
        zwj = _Lb.zwj,
        cm = _Lb.cm,
        bk = _Lb.bk,
        cr = _Lb.cr,
        lf = _Lb.lf,
        nl = _Lb.nl,
        wj = _Lb.wj,
        gl = _Lb.gl,
        op = _Lb.op,
        cl = _Lb.cl,
        cp = _Lb.cp,
        ex = _Lb.ex,
        sy = _Lb.sy,
        qu = _Lb.qu,
        is_ = _Lb.is_,
        ns = _Lb.ns,
        b2 = _Lb.b2,
        cb = _Lb.cb,
        hy = _Lb.hy,
        ba = _Lb.ba,
        bb = _Lb.bb,
        in_ = _Lb.in_,
        pr = _Lb.pr,
        po = _Lb.po,
        id = _Lb.id,
        eb = _Lb.eb,
        em = _Lb.em,
        jl = _Lb.jl,
        jv = _Lb.jv,
        jt = _Lb.jt,
        h2 = _Lb.h2,
        h3 = _Lb.h3,
        ap = _Lb.ap,
        ak = _Lb.ak,
        as_ = _Lb.as_,
        vf = _Lb.vf,
        vi = _Lb.vi,
        ri = _Lb.ri;
    const hard = {bk, cr, lf, nl};
    const resets = {bk, cr, lf, nl, sp, zw};
    // LB1: resolve ambiguous/default classes before evaluating rules.
    for (var i = 0; i < classes.length; i++) {
      if (const {_Lb.ai, _Lb.sg, _Lb.xx}.contains(classes[i])) {
        classes[i] = al;
      }
      if (classes[i] == _Lb.sa) {
        classes[i] = props[i] & 64 != 0 ? cm : al;
      }
      if (classes[i] == _Lb.cj) {
        classes[i] = ns;
      }
    }
    final breaks = List<bool?>.filled(runes.length + 1, null);
    breaks[0] = false; // LB2
    breaks[runes.length] = true; // LB3
    for (var i = 1; i < runes.length; i++) {
      final a = classes[i - 1], b = classes[i];
      var beforeSpaces = i - 1;
      while (beforeSpaces >= 0 && classes[beforeSpaces] == sp) {
        beforeSpaces--;
      }
      if (a == bk) {
        breaks[i] = true;
      } // LB4
      else if (a == cr && b == lf) {
        breaks[i] = false;
      } // LB5
      else if (hard.contains(a)) {
        breaks[i] = true;
      } else if (hard.contains(b)) {
        breaks[i] = false;
      } // LB6
      else if (b == sp || b == zw) {
        breaks[i] = false;
      } // LB7
      else if (beforeSpaces >= 0 && classes[beforeSpaces] == zw) {
        breaks[i] = true;
      } // LB8
      else if (a == zwj) {
        breaks[i] = false;
      } // LB8a
    }
    // LB9: skip attached marks in all subsequent context matching. Keep their
    // original offsets and earlier rule decisions, including mandatory breaks.
    final kept = <int>[];
    var base = -1;
    for (var i = 0; i < classes.length; i++) {
      final combining = classes[i] == cm || classes[i] == zwj;
      if (combining && base >= 0 && !resets.contains(classes[base])) {
        breaks[i] ??= false;
      } else {
        kept.add(i);
        if (combining) {
          // LB10
          classes[i] = al;
          runes[i] = 0x41;
          props[i] = _unicodeBreakProperty(0x41);
        }
      }
      if (!combining) {
        base = i;
      }
    }
    _Lb? c(int i) => i >= 0 && i < kept.length ? classes[kept[i]] : null;
    int char(int i) => i >= 0 && i < kept.length ? runes[kept[i]] : -1;
    bool flag(int i, int bit) =>
        i >= 0 && i < kept.length && props[kept[i]] & bit != 0;
    int skip(int i, Set<_Lb> values) {
      while (i >= 0 && values.contains(c(i))) {
        i--;
      }
      return i;
    }

    bool aksara(int i) => const {ak, as_}.contains(c(i)) || char(i) == 0x25cc;
    var regionalCount = 0;
    for (var i = 1; i < kept.length; i++) {
      final original = kept[i];
      final a = c(i - 1), b = c(i), next = c(i + 1);
      regionalCount = a == ri ? regionalCount + 1 : 0;
      if (breaks[original] != null) {
        continue;
      }
      final beforeSpaces = skip(i - 1, const {sp});
      final beforeNumber = skip(i - 1, const {sy, is_});
      var beforeClosedNumber = i - 1;
      if (const {cl, cp}.contains(c(beforeClosedNumber))) {
        beforeClosedNumber--;
      }
      beforeClosedNumber = skip(beforeClosedNumber, const {sy, is_});
      bool allowed;
      if (a == wj || b == wj) {
        allowed = false;
      } // LB11
      else if (a == gl) {
        allowed = false;
      } // LB12
      else if (!const {sp, ba, hy}.contains(a) && b == gl) {
        allowed = false;
      } // LB12a
      else if (const {cl, cp, ex, sy}.contains(b)) {
        allowed = false;
      } // LB13
      else if (c(beforeSpaces) == op) {
        allowed = false;
      } // LB14
      else if (flag(beforeSpaces, 128) &&
          c(beforeSpaces) == qu &&
          (beforeSpaces == 0 ||
              const {bk, cr, lf, nl, op, qu, gl, sp, zw}
                  .contains(c(beforeSpaces - 1)))) {
        allowed = false; // LB15a
      } else if (flag(i, 256) &&
          b == qu &&
          (original == runes.length - 1 ||
              const {sp, gl, wj, cl, qu, cp, ex, is_, sy, bk, cr, lf, nl, zw}
                  .contains(next))) {
        allowed = false; // LB15b
      } else if (a == sp && b == is_ && next == nu) {
        allowed = true;
      } // LB15c
      else if (b == is_) {
        allowed = false;
      } // LB15d
      else if (const {cl, cp}.contains(c(beforeSpaces)) && b == ns) {
        allowed = false;
      } // LB16
      else if (c(beforeSpaces) == b2 && b == b2) {
        allowed = false;
      } // LB17
      else if (a == sp) {
        allowed = true;
      } // LB18
      else if ((b == qu && !flag(i, 128)) || (a == qu && !flag(i - 1, 256))) {
        allowed = false;
      } // LB19
      else if ((!flag(i - 1, 1024) && b == qu) ||
          (b == qu && (!flag(i + 1, 1024) || original == runes.length - 1)) ||
          (a == qu && !flag(i, 1024)) ||
          (a == qu && (!flag(i - 2, 1024) || kept[i - 1] == 0))) {
        allowed = false;
      } // LB19a
      else if (a == cb || b == cb) {
        allowed = true;
      } // LB20
      else if (const {hy, ba}.contains(a) &&
          b == al &&
          (a == hy || char(i - 1) == 0x2010) &&
          (kept[i - 1] == 0 ||
              const {bk, cr, lf, nl, sp, zw, cb, gl}.contains(c(i - 2)))) {
        allowed = false; // LB20a
      } else if (const {ba, hy, ns}.contains(b) || a == bb) {
        allowed = false;
      } // LB21
      else if (const {hy, ba}.contains(a) && c(i - 2) == hl && b != hl) {
        allowed = false;
      } // LB21a
      else if (a == sy && b == hl) {
        allowed = false;
      } // LB21b
      else if (b == in_) {
        allowed = false;
      } // LB22
      else if ((const {al, hl}.contains(a) && b == nu) ||
          (a == nu && const {al, hl}.contains(b))) {
        allowed = false;
      } // LB23
      else if ((a == pr && const {id, eb, em}.contains(b)) ||
          (const {id, eb, em}.contains(a) && b == po)) {
        allowed = false;
      } // LB23a
      else if ((const {pr, po}.contains(a) && const {al, hl}.contains(b)) ||
          (const {al, hl}.contains(a) && const {pr, po}.contains(b))) {
        allowed = false;
      } // LB24
      else if ((c(beforeClosedNumber) == nu && const {po, pr}.contains(b)) ||
          (const {po, pr}.contains(a) &&
              b == op &&
              (next == nu || (next == is_ && c(i + 2) == nu))) ||
          (const {po, pr, hy, is_}.contains(a) && b == nu) ||
          (c(beforeNumber) == nu && b == nu)) {
        allowed = false;
      } // LB25
      else if ((a == jl && const {jl, jv, h2, h3}.contains(b)) ||
          (const {jv, h2}.contains(a) && const {jv, jt}.contains(b)) ||
          (const {jt, h3}.contains(a) && b == jt)) {
        allowed = false;
      } // LB26
      else if ((const {jl, jv, jt, h2, h3}.contains(a) && b == po) ||
          (a == pr && const {jl, jv, jt, h2, h3}.contains(b))) {
        allowed = false;
      } // LB27
      else if (const {al, hl}.contains(a) && const {al, hl}.contains(b)) {
        allowed = false;
      } // LB28
      else if ((a == ap && aksara(i)) ||
          (aksara(i - 1) && const {vf, vi}.contains(b)) ||
          (aksara(i - 2) && a == vi && (b == ak || char(i) == 0x25cc)) ||
          (aksara(i - 1) && aksara(i) && next == vf)) {
        allowed = false;
      } // LB28a
      else if (a == is_ && const {al, hl}.contains(b)) {
        allowed = false;
      } // LB29
      else if ((const {al, hl, nu}.contains(a) && b == op && !flag(i, 1024)) ||
          (a == cp && !flag(i - 1, 1024) && const {al, hl, nu}.contains(b))) {
        allowed = false;
      } // LB30
      else if (a == ri && b == ri && regionalCount.isOdd) {
        allowed = false;
      } // LB30a
      else if (b == em &&
          (a == eb || (flag(i - 1, 512) && flag(i - 1, 2048)))) {
        allowed = false;
      } // LB30b
      else {
        allowed = true;
      } // LB31
      breaks[original] = allowed;
    }
    return [
      for (var i = 1; i <= runes.length; i++)
        if (breaks[i] ?? true)
          UnicodeLineBreak(starts[i], mandatory: hard.contains(classes[i - 1]))
    ];
  }
}

class UnicodeLineBreak {
  const UnicodeLineBreak(this.offset, {this.mandatory = false});
  final int offset;
  final bool mandatory;
}

int _unicodeBreakProperty(int rune) {
  var lo = 0, hi = _lineBreakData.length ~/ 3 - 1;
  while (lo <= hi) {
    final middle = (lo + hi) >> 1;
    final index = middle * 3;
    if (rune < _lineBreakData[index]) {
      hi = middle - 1;
    } else if (rune > _lineBreakData[index + 1]) {
      lo = middle + 1;
    } else {
      return _lineBreakData[index + 2];
    }
  }
  throw RangeError.range(rune, 0, 0x10ffff);
}
