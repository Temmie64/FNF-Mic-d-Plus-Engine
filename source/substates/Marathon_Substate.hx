package substates;

import backend.Mods;
import backend.Song;
import backend.Difficulty;
import backend.ModeDifficulty;
import states.PlaySelectionState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import states.MenuMarathon;
import sys.FileSystem;

class Marathon_Substate extends MusicBeatSubstate
{
	public static var curSelected:Int = 0;
	public static var presets:Array<String>;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var optionNames:Array<String>;
	var selectable:Bool = false;
	var closing:Bool = false;

	public function new()
	{
		super();
		if (!FileSystem.isDirectory('presets/marathon'))
			FileSystem.createDirectory('presets/marathon');

		presets = [];
		try
		{
			presets = FileSystem.readDirectory('presets/marathon');
			presets.remove('current');
		}
		catch (_:Dynamic) {}

		var canPlay:String = PlayState.storyPlaylist.length > 0 && PlayState.difficultyPlaylist.length > 0 ? 'play' : 'no';
		var canEdit:String = PlayState.storyPlaylist.length > 0 ? 'edit' : 'no';
		optionNames = [canPlay, canEdit, 'clear', 'save', presets.length > 0 ? 'load' : 'no', 'exit'];
		curSelected = Std.int(FlxMath.bound(curSelected, 0, optionNames.length - 1));

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);
		var atlas = Paths.getSparrowAtlas('MicUp/Modi_Buttons');
		for (i in 0...optionNames.length)
		{
			var item:FlxSprite = new FlxSprite(0, 20 + (i * 105));
			item.frames = atlas;
			item.animation.addByPrefix('idle', optionNames[i], 24, true);
			item.animation.play('idle');
			item.ID = i;
			item.scrollFactor.set();
			item.antialiasing = true;
			item.screenCenter(X);
			menuItems.add(item);
		}
		new FlxTimer().start(0.1, function(_) selectable = true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (!selectable || closing)
			return;

		if (controls.UI_UP_P)
		{
			changeItem(-1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
		}
		if (controls.UI_DOWN_P)
		{
			changeItem(1);
			FlxG.sound.play(Paths.sound('scrollMenu'), 100);
		}
		if (controls.BACK)
		{
			closing = true;
			FlxG.sound.play(Paths.sound('cancelMenu'), 100);
			FlxG.state.closeSubState();
			MenuMarathon.substated = false;
			return;
		}
		if (controls.ACCEPT)
			acceptOption();

		for (item in menuItems.members)
		{
			item.scale.set(FlxMath.lerp(item.scale.x, item.ID == curSelected ? 1.2 : 0.4, 0.16),
				FlxMath.lerp(item.scale.y, item.ID == curSelected ? 1.2 : 0.4, 0.16));
			item.screenCenter(X);
			item.y = 20 + (item.ID * 105);
		}
	}

	function changeItem(change:Int):Void
	{
		curSelected += change;
		if (curSelected < 0)
			curSelected = optionNames.length - 1;
		if (curSelected >= optionNames.length)
			curSelected = 0;
	}

	function acceptOption():Void
	{
		switch (optionNames[curSelected])
		{
			case 'play':
				if (validatePlaylist())
				{
					var songName:String = PlayState.storyPlaylist[0].toLowerCase();
					var diffName:String = ModeDifficulty.fromPlaylist(PlayState.difficultyPlaylist[0]);
					Mods.currentModDirectory = PlayState.storyFolderPlaylist[0];
					var available:Array<String> = ModeDifficulty.available(songName, null, diffName);
					Difficulty.copyFrom(available);
					PlayState.storyDifficulty = ModeDifficulty.indexOf(diffName);
					if (Song.loadFromJson(ModeDifficulty.chartName(songName, diffName), songName) != null)
					{
						PlayState.difficultyPlaylist[0] = diffName;
						closing = true;
						PlayState.campaignScore = 0;
						FlxG.sound.play(Paths.sound('confirmMenu'), 100);
						FlxG.state.closeSubState();
						FlxG.state.openSubState(new ChartType());
						MenuMarathon.no = true;
					}
					else
						resetUnavailablePlaylist();
				}
			case 'edit':
				closing = true;
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Marathon_Edit());
			case 'clear':
				PlayState.storyPlaylist = [];
				PlayState.difficultyPlaylist = [];
				PlayState.storyFolderPlaylist = [];
				MenuMarathon.saveCurrent();
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Marathon_Substate());
			case 'save':
				closing = true;
				Substate_PresetSave.coming = 'Marathon';
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Substate_PresetSave());
			case 'load':
				closing = true;
				Substate_PresetLoad.coming = 'Marathon';
				FlxG.state.closeSubState();
				FlxG.state.openSubState(new Substate_PresetLoad());
			case 'exit':
				closing = true;
				FlxG.sound.play(Paths.sound('confirmMenu'), 100);
				MusicBeatState.switchState(new PlaySelectionState());
		}
	}

	function validatePlaylist():Bool
	{
		if (PlayState.storyPlaylist.length == 0
			|| PlayState.storyPlaylist.length != PlayState.difficultyPlaylist.length
			|| PlayState.storyPlaylist.length != PlayState.storyFolderPlaylist.length)
			return resetUnavailablePlaylist();

		var changed:Bool = false;
		for (i in 0...PlayState.storyPlaylist.length)
		{
			Mods.currentModDirectory = PlayState.storyFolderPlaylist[i];
			var songName:String = PlayState.storyPlaylist[i].toLowerCase();
			var difficulty:String = ModeDifficulty.fromPlaylist(PlayState.difficultyPlaylist[i]);
			if (Song.resolveChartPath(ModeDifficulty.chartName(songName, difficulty), songName) == null)
				return resetUnavailablePlaylist();
			if (PlayState.difficultyPlaylist[i] != difficulty)
				changed = true;
			PlayState.difficultyPlaylist[i] = difficulty;
		}
		if (changed)
			MenuMarathon.saveCurrent();
		return true;
	}

	function resetUnavailablePlaylist():Bool
	{
		PlayState.storyPlaylist = [];
		PlayState.difficultyPlaylist = [];
		PlayState.storyFolderPlaylist = [];
		MenuMarathon.saveCurrent();
		closing = true;
		FlxG.state.closeSubState();
		FlxG.state.openSubState(new Marathon_Substate());
		return false;
	}
}
