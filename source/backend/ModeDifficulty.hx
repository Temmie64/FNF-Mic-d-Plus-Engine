package backend;

using StringTools;

class ModeDifficulty
{
	public static function available(song:String, ?weekDifficulties:String, ?requested:String):Array<String>
	{
		var candidates:Array<String> = [];
		addCandidates(candidates, weekDifficulties);
		addCandidates(candidates, requested);
		if (Difficulty.list != null)
			for (difficulty in Difficulty.list)
				addCandidates(candidates, difficulty);
		for (difficulty in Difficulty.defaultList)
			addCandidates(candidates, difficulty);
		for (difficulty in ['Noob', 'Expert', 'Insane', 'Crazy', 'Flip', 'Fucked', 'Hell', 'Remix', 'Erect', 'Nightmare'])
			addCandidates(candidates, difficulty);

		var available:Array<String> = [];
		for (difficulty in candidates)
		{
			if (Song.resolveChartPath(chartName(song, difficulty), song) != null)
				available.push(difficulty);
		}

		if (available.length == 0 && Song.resolveChartPath(Paths.formatToSongPath(song), song) != null)
			available.push(Difficulty.getDefault());

		return available;
	}

	public static function chartName(song:String, difficulty:String):String
	{
		var baseSong:String = Paths.formatToSongPath(song);
		var formattedDifficulty:String = Paths.formatToSongPath(difficulty);
		return formattedDifficulty == Paths.formatToSongPath(Difficulty.getDefault())
			? baseSong
			: baseSong + '-' + formattedDifficulty;
	}

	public static function fromPlaylist(value:String):String
	{
		if (value == null || value.trim().length == 0)
			return Difficulty.getDefault();

		var legacyIndex:Null<Int> = Std.parseInt(value);
		if (legacyIndex == null)
			return value;

		return switch (legacyIndex)
		{
			case 0: 'Noob';
			case 1: 'Easy';
			case 2: 'Normal';
			case 3: 'Hard';
			case 4: 'Expert';
			case 5: 'Insane';
			default: Difficulty.getDefault();
		};
	}

	public static function indexOf(difficulty:String):Int
	{
		var index:Int = Difficulty.list.indexOf(difficulty);
		if (index >= 0)
			return index;

		return switch (Paths.formatToSongPath(difficulty))
		{
			case 'noob': 0;
			case 'easy': 1;
			case 'normal': 2;
			case 'hard': 3;
			case 'expert': 4;
			case 'insane': 5;
			default: 0;
		};
	}

	public static function findAvailable(difficulties:Array<String>, requested:String):Null<String>
	{
		var formatted:String = Paths.formatToSongPath(requested);
		for (difficulty in difficulties)
			if (Paths.formatToSongPath(difficulty) == formatted)
				return difficulty;
		return null;
	}

	static function addCandidates(candidates:Array<String>, value:String):Void
	{
		if (value == null)
			return;

		for (difficulty in value.split(','))
		{
			var trimmed:String = difficulty.trim();
			if (trimmed.length == 0)
				continue;

			var formatted:String = Paths.formatToSongPath(trimmed);
			var duplicate:Bool = false;
			for (candidate in candidates)
				if (Paths.formatToSongPath(candidate) == formatted)
				{
					duplicate = true;
					break;
				}
			if (!duplicate)
				candidates.push(trimmed);
		}
	}
}
