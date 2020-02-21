var myVar = setInterval(getTemperatureData, 5000);


var HttpClient = function() {
    this.get = function(aUrl, aCallback) {
        var anHttpRequest = new XMLHttpRequest();
        anHttpRequest.onreadystatechange = function() { 
            if (anHttpRequest.readyState == 4 && anHttpRequest.status == 200)
                aCallback(JSON.parse(anHttpRequest.responseText));
        }

        anHttpRequest.open( "GET", aUrl, true );            
        anHttpRequest.send( );
    }

        this.post = function(aUrl, params, aCallback) {
        var anHttpRequest = new XMLHttpRequest();
        anHttpRequest.onreadystatechange = function() { 
            if (anHttpRequest.readyState == 4 && anHttpRequest.status == 200)
                aCallback(JSON.parse(anHttpRequest.responseText));
        }

        anHttpRequest.open( "POST", aUrl, true ); 

        anHttpRequest.setRequestHeader("Content-type", "application/json; charset=utf-8");
		anHttpRequest.setRequestHeader("Content-length", params.length);
		anHttpRequest.setRequestHeader("Connection", "close");  



        anHttpRequest.send( params );
    }
}

var client = new HttpClient();


function compare(a, b) {
	const dateA = new Date(a.timestamp);
	const dateB = new Date(b.timestamp);

	let comparison = 0;

	if(dateA.valueOf() < dateB.valueOf()) {
		comparison = 1;
	} else {
		comparison = -1;
	}

	return comparison;
}


function updateValues() {
	var name = document.getElementById('new_name').value;
	var location = document.getElementById('new_location').value;
	var number = document.getElementById('new_number').value;
	var threshold = document.getElementById('new_threshold').value;

	params = JSON.stringify({'name':name, 'location':location, 'number':number, 'threshold':threshold});
	client.post("http://localhost:8080/sky/event/5vWSGgGiHHNh8muoXmfsN6/null/sensor/profile_updated", params, function(response) {
		getValues();
	});
}





function getValues() {
	client.get("http://localhost:8080/sky/event/5vWSGgGiHHNh8muoXmfsN6/null/sensor/get_profile", function(response) {
    	

		console.log(response);
    	console.log(response.directives);

    	options = response.directives[0].options


    	document.getElementById('name').innerHTML = options.name;
    	document.getElementById('number').innerHTML = options.number;
    	document.getElementById('location').innerHTML = options.location;
    	document.getElementById('threshold').innerHTML = options.threshold;
});
}

function getTemperatureData() {
	client.get("http://localhost:8080/sky/cloud/5vWSGgGiHHNh8muoXmfsN6/temperature_store/temperatures", function(response) {
    	table = document.getElementById('tableBody');
    	table.innerHTML="";
    	response.sort(compare).forEach( function(element, i) {
    		if (i == 0) {
    			document.getElementById('currentTemp').innerHTML = element.temperature + '°F';
    		}
    		var row = table.insertRow(-1);
    		var cell1 = row.insertCell(0);
    		var cell2 = row.insertCell(1);
    		cell1.innerHTML = element.timestamp;
    		cell2.innerHTML = element.temperature;
    		cell2.align = 'center';
    	});
    	//document.getElementById('temps').innerHTML = result;
});

	client.get("http://localhost:8080/sky/cloud/5vWSGgGiHHNh8muoXmfsN6/temperature_store/threshold_violations", function(response) {
    	table = document.getElementById('tableBody2');
    	table.innerHTML="";
    	response.sort(compare).forEach( function(element, i) {
    		var row = table.insertRow(-1);
    		var cell1 = row.insertCell(0);
    		var cell2 = row.insertCell(1);
    		cell1.innerHTML = element.timestamp;
    		cell2.innerHTML = element.temperature;
    		cell2.align = 'center';
    	});
    	//document.getElementById('temps').innerHTML = result;
});
}