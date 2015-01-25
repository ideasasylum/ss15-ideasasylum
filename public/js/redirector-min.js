function loadRules(token, callback) {
  var url = "https://resplendent-torch-5273.firebaseio.com/published/";

  var xobj = new XMLHttpRequest();
  xobj.overrideMimeType("application/json");
  xobj.open('GET', url+token+'.json', true);
  xobj.onreadystatechange = function () {
    if (xobj.readyState == 4 && xobj.status == "200") {
      callback(xobj.responseText);
    }
  };
  xobj.send(null);
}

token = window.RedirectYourTraffic.token;
if(document.referrer != undefined || document.referrer.length > 0) {
  loadRules(token, function(resp){
    rules = JSON.parse(resp)
    console.log(rules);

    // Test rules
    rules.push({referrer: 'ss15-ideasasylum.divshot.io',
                dest: 'http://ss15-ideasasylum.divshot.io/#success'});

    rules.push({referrer: 'jamies-macbook-air-3.local:5757',
                dest: 'http://jamies-macbook-air-3.local:5757/#success'});

    // for each rule
    rules.forEach(function(rule, index){
      // test the referrer against the domain
      regex = "^.*"+rule.referrer+".*$"
      matched = document.referrer.match(regex);
      if(matched){
        // redirect if necessary
        window.location.replace(rule.dest);
        return
      }
    });
  });
}


