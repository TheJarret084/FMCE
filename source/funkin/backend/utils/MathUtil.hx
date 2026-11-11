package funkin.backend.utils;

import haxe.macro.Expr;

final class MathUtil {
        public static inline var EULER:Float = 2.718281828459;

        public static function maxInt(...args:Int):Int {
                var max = args[0];
                for(i in 1...args.length) {
                        var arg = args[i];
                        if(arg > max)
                                max = arg;
                }
                return max;
        }

        public static function minInt(...args:Int):Int {
                var min = args[0];
                for(i in 1...args.length) {
                        var arg = args[i];
                        if(arg < min)
                                min = arg;
                }
                return min;
        }

        public static function max(...args:Float):Float {
                var max = args[0];
                for(i in 1...args.length) {
                        var arg = args[i];
                        if(arg > max)
                                max = arg;
                }
                return max;
        }

        public static function min(...args:Float):Float {
                var min = args[0];
                for(i in 1...args.length) {
                        var arg = args[i];
                        if(arg < min)
                                min = arg;
                }
                return min;
        }

        public static function lessThan(a:Float, b:Float, margin:Float = 0.0000001):Bool {
                return a < b - margin;
        }

        public static function lessThanEqual(a:Float, b:Float, margin:Float = 0.0000001):Bool {
                return a <= b - margin;
        }

        public static function greaterThan(a:Float, b:Float, margin:Float = 0.0000001):Bool {
                return a > b + margin;
        }

        public static function greaterThanEqual(a:Float, b:Float, margin:Float = 0.0000001):Bool {
                return a >= b + margin;
        }

        public static function equal(a:Float, b:Float, margin:Float = 0.0000001):Bool {
                return Math.abs(a - b) <= margin;
        }

        public static function notEqual(a:Float, b:Float, margin:Float = 0.0000001):Bool {
                return Math.abs(a - b) > margin;
        }

        public static function smoothStep(edge0:Float, edge1:Float, x:Float):Float {
                var t = (x - edge0) / (edge1 - edge0);
                var clamped = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
                return clamped * clamped * (3.0 - 2.0 * clamped);
        }

        public static function inverseLerp(a:Float, b:Float, v:Float):Float {
                return (v - a) / (b - a);
        }

        public static function fract(v:Float):Float {
                return v - Math.floor(v);
        }

        @:dox(hide) public static macro function maxSmart(..._args:Expr):Expr {
                return genericMinMaxSmart(_args.toArray(), "Math.max");
        }

        @:dox(hide) public static macro function minSmart(..._args:Expr):Expr {
                return genericMinMaxSmart(_args.toArray(), "Math.min");
        }

        #if macro
        @:dox(hide) private static function genericMinMaxSmart(_args:Array<Expr>, funcPath:String):Expr {
                var args = _args.copy();
                if (args.length == 0) return macro 0;

                var func = funcPath.split(".");

                function nested(lst:Array<Expr>):Expr {
                        if (lst.length == 1) {
                                return macro ${lst[0]};
                        } else if (lst.length == 2) {
                                return macro $p{func}(${lst[0]}, ${lst[1]});
                        } else {
                                var mid = Std.int(lst.length / 2);
                                return macro $p{func}(${nested(lst.slice(0, mid))}, ${nested(lst.slice(mid, lst.length))});
                        }
                }

                var expr = nested(args);

                return macro $expr;
        }
        #end
}
