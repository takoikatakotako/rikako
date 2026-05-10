var imageAry = new Array();
imageAry[0] = "images/screen1.png";
imageAry[1] = "images/screen2.png";
imageAry[2] = "images/screen3.png";
imageAry[3] = "images/screen4.png";
imageAry[4] = "images/screen5.png";

var nowImage = 0;

window.onload = function(){
// ページ読み込み時に実行したい処理
  setInterval('changeImage()',2000);
}


function changeImage(){
  if(nowImage == imageAry.length){
    nowImage = 0;
    console.log("nowImageを0にします。");
    changeImage();
  }else{
    console.log("表示する画像:%s",imageAry[nowImage]);
    //画像を切り替える
    document.getElementById("iPhoneScreen").src=imageAry[nowImage];
    nowImage ++;
  }
}