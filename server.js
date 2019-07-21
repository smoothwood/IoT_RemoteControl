var v4 = require("aws-signaturev4-generator");
var mqtt = require("mqtt");
var bodyParser = require('body-parser')
var express = require("express");
var app = express();
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());
 
var preSignedUrl = v4.generate_signv4_mqtt("xxxxx.iot.ap-northeast-1.amazonaws.com", "ap-northeast-1", "your secret key id", "your secret key");
 
var port = 443;

var codeAry = {};
var codeAryLength = 0;
 
var client = mqtt.connect(preSignedUrl,
{
    connectTimeout: 5 * 1000,
    port: port,
});
 
client.on('connect', function () {
    //client.subscribe(topic, function (err) {
    //    if (!err) {
    //        //client.publish(topic, 'Hello mqtt')
    //        console.log("connected...");
    //    }
    //})
    console.log("MQTT connected...");
})
 
//client.on('message', function (topic, message) {
//    console.log(message.toString())
//    i = i + 1
//    client.publish(topic, 'Hello mqtt ' + String(i))
//})
 
app.listen(80,function () {
    console.log("http://101.132.104.40:80")
})
 
// call from mobile
app.post('/command', function (req, res) {
    console.log(req.body);
    console.log(req.body.topic);
    var topic = req.body.topic;
    var message = req.body.message;
    client.publish(topic, message);
    res.end();
});

// call from ESP12E
app.post('/data', function (req, res) {
    var code = req.body.code;
    var codeLength = req.body.codeLength;
    var receivedCode = {};
    receivedCode.code = code;
    receivedCode.codeLength = codeLength;
    receivedCode.desc = codeAryLength;
    codeAry[codeAryLength++] = receivedCode;
    console.log(codeAry);
    res.end("OK");
});


app.get('/data', function (req, res) {
    var id = req.query.id;
    if(id==null){
        var keys = Object.keys(codeAry);
        console.log(keys);
        var commandList = [];
        
        for(var i = 0; i<keys.length;i++){
            var command = {};
            command.key = keys[i];
            command.desc = codeAry[keys[i]].desc;
            commandList.push(command);
        }
        console.log(JSON.stringify(commandList));
        res.json(JSON.stringify(commandList));
    }
    else{
        console.log(codeAry[id]);
        res.json(codeAry[id]);
    }
    res.end();
});

app.put('/data',function(req,res){
    var id = req.body.id;
    var desc = req.body.desc;
    codeAry[id].desc = desc;
    console.log(codeAry);
    res.end("OK");
});
