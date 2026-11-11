package funkin.backend.utils;

final class SortedArrayUtil {

	public static function binarySearch<T>(array:Array<T>, val:Float, getVal:T->Float):Int {
		if (array.length <= 0) return 0;
		if (getVal(array[0]) > val) return 0;
		if (getVal(array[array.length-1]) < val) return array.length;

		var iMin:Int = 0;
		var iMax:Int = array.length-1;

		var i:Int = 0;
		var mid:Float;
		while(iMin <= iMax) {
			i = Math.floor(iMin + (iMax - iMin) / 2);
			mid = getVal(array[i]);
			if (mid < val)
				iMin = i+1
			else if (mid > val)
				iMax = i-1;
			else {
				iMin = i;
				break;
			}
		}
		return iMin;
	}

	public static inline function addSorted<T>(array:Array<T>, val:T, getVal:T->Float) {
		if (val != null)
			array.insert(binarySearch(array, getVal(val), getVal), val);
	}

	public static inline function removeSorted<T>(array:Array<T>, val:T, getVal:T->Float) {
		var index = binarySearch(array, getVal(val), getVal);
		if (index != -1)
			array.splice(index, 1);
	}
}
