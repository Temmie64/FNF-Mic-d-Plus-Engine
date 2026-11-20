package backend;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map<String, Int>();
	public static var endlessScores:Map<String, Int> = new Map<String, Int>();
	public static var songRating:Map<String, Float> = new Map<String, Float>();

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var daSong:String = formatSong(song, diff);
		setScore(daSong, 0);
		setRating(daSong, 0);
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);
		setWeekScore(daWeek, 0);
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1):Void
	{
		if (song == null)
			return;
		var daSong:String = formatSong(song, diff);

		if (songScores.exists(daSong))
		{
			if (songScores.get(daSong) < score)
			{
				setScore(daSong, score);
				if (rating != -1)
					setRating(daSong, rating);
			}
			// If the score is the same but the rating is better, update only the rating
			else if (songScores.get(daSong) == score && rating != -1)
			{
				var currentRating:Float = getRating(song, diff);
				if (rating > currentRating)
					setRating(daSong, rating);
			}
		}
		else
		{
			setScore(daSong, score);
			if (rating != -1)
				setRating(daSong, rating);
		}
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else
			setWeekScore(daWeek, score);
	}

	public static function saveMarathonScore(score:Int = 0):Void
	{
		var previous:Null<Int> = FlxG.save.data.marathonScore;
		if (previous == null || score > previous)
		{
			FlxG.save.data.marathonScore = score;
			FlxG.save.flush();
		}
	}

	public static function saveEndlessScore(song:String, score:Int = 0, ?folder:String):Void
	{
		if (song == null)
			return;

		var key:String = getEndlessScoreKey(song, folder);
		var legacyKey:String = Paths.formatToSongPath(song);
		var previous:Int = 0;
		if (endlessScores.exists(key))
			previous = endlessScores.get(key);
		else if (folder != null && folder.length > 0 && endlessScores.exists(legacyKey))
			previous = endlessScores.get(legacyKey);
		if (score > previous)
		{
			endlessScores.set(key, score);
			FlxG.save.data.endlessScores = endlessScores;
			FlxG.save.flush();
		}
	}

	public static function saveSurvivalScore(score:Int = 0, timeLeft:Float = 0):Void
	{
		var previous:Null<Int> = FlxG.save.data.survivalScore;
		if (previous == null || score > previous)
		{
			FlxG.save.data.survivalScore = score;
			FlxG.save.data.survivalTime = timeLeft;
			FlxG.save.flush();
		}
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}

	static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + Difficulty.getFilePath(diff);
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		return songScores.exists(daSong) ? songScores.get(daSong) : 0;
	}

	public static function getRating(song:String, diff:Int):Float
	{
		var daSong:String = formatSong(song, diff);
		return songRating.exists(daSong) ? songRating.get(daSong) : 0;
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var daWeek:String = formatSong(week, diff);
		return weekScores.exists(daWeek) ? weekScores.get(daWeek) : 0;
	}

	public static function getEndless(song:String, ?folder:String):Int
	{
		if (song == null)
			return 0;

		var key:String = getEndlessScoreKey(song, folder);
		if (endlessScores.exists(key))
			return endlessScores.get(key);

		return folder != null && folder.length > 0 && endlessScores.exists(Paths.formatToSongPath(song))
			? endlessScores.get(Paths.formatToSongPath(song))
			: 0;
	}

	static function getEndlessScoreKey(song:String, ?folder:String):String
	{
		var songKey:String = Paths.formatToSongPath(song);
		return folder != null && folder.length > 0
			? Paths.formatToSongPath(folder) + '::' + songKey
			: songKey;
	}

	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
			weekScores = FlxG.save.data.weekScores;

		if (FlxG.save.data.songScores != null)
			songScores = FlxG.save.data.songScores;

		if (FlxG.save.data.endlessScores != null)
			endlessScores = FlxG.save.data.endlessScores;

		if (FlxG.save.data.songRating != null)
			songRating = FlxG.save.data.songRating;
	}
}

