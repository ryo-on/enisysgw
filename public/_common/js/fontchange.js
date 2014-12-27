//
window.onload = getCookie;

function getCookie(){
	zoom = "";
	cName = "GD_FontSize=";
	tmpCookie = document.cookie + ";";
	start = tmpCookie.indexOf(cName);
	if (start != -1)
	{
		end = tmpCookie.indexOf(";", start);
		zoom = tmpCookie.substring(start + cName.length, end);
		document.getElementById(target).style.fontSize = zoom+'%';
		setFontIcon(zoom);
	} else {
		document.getElementById(target).style.fontSize = "100%";
		setFontIcon('100');
	}
}
////文字拡大・縮小//////////////////////////////////////////////////////////////////////////////
var target = "container";	//*文字拡大・縮小対象エリア（ID名）
//
function setCookie(s){
	cName = "GD_FontSize=";
	exp = new Date();
	exp.setTime(exp.getTime() + 31536000000);
	document.cookie = cName + s + "; path=/; expires=" + exp.toGMTString();
}
//
function setFontSize(par) {
	if(!par || par=="") par = "100";
	document.getElementById(target).style.fontSize = par+'%';
	setCookie(par);
	setFontIcon(par);
}
function setFontIcon(zoom) {
	if (zoom == "120") {
		document.getElementById('icon120');
		document.getElementById('icon100');
		document.getElementById('icon90');
		
	}  else if (zoom == "90") {
		document.getElementById('icon120');
		document.getElementById('icon100');
		document.getElementById('icon90');

	}  else {
		document.getElementById('icon120');
		document.getElementById('icon100');
		document.getElementById('icon90');
	}
}
//
////文字拡大・縮小//////////////////////////////////////////////////////////////////////////////

