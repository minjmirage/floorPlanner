package 
{
	import flash.display.Sprite;
	import ButtonsMenu;
	
	[SWF(width = "1024", height = "768", backgroundColor = "#FFFFFF", frameRate = "30")];
		
	/**
	 * ...
	 * @author Minjmirage
	 */
	public class Testing extends Sprite
	{
		public function Testing():void
		{
			
			var men:ButtonsMenu = 
			new ButtonsMenu("HAHAHA MENU",Vector.<Sprite>([makeBtn(),makeBtn(),makeBtn()]),
							function(idx:int):void {trace("btn "+idx+" pressed");});
			
			men.createTabs(Vector.<String>(["1","2","CAT"]),function(idx:int):void {trace("tab "+idx+" pressed");});
			
			addChild(men);
		}//endFunction
		
		
		private function makeBtn():Sprite
		{
			var s:Sprite = new Sprite();
			s.graphics.beginFill(0x336699,1);
			s.graphics.drawRect(0,0,70,70);
			s.graphics.endFill();
			return s;
		}//endfunction
	}//endClass
}//endpackage