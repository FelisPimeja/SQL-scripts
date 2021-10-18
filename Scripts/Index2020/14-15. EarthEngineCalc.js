// Скрипт для расчёта 14 и 15 индикаторов
// на основе автоматически отобранных снимков Sentinel в Google Earth Engine

// Для работы скрипта нужен загруженный в Earth Engine shp с границами городов и поменять ссылку на ассет aoi
// Также надо поменять как минимум год в строке 105 (var ndvi = createMediansNDVI(collection,feature.geometry(), 2020, 20, 5, 9);)

// На выходе скрипт выгружает таблицу с площадями озеленения с разной отсечкой по NDVI для дальнейшего расчёта индикаторов
// Время работы - несколько часов (~3 каажется)
// Чтобы скачать расты для визуализации индикаторов воспользуйтесь скриптом "14-15. EarthEngineViz.js"

// Выбираем снимки Sentinel
var collection = ee.ImageCollection('COPERNICUS/S2_SR');

// Подгружаем границы городов
var aoi = ee.FeatureCollection('users/apetrov/cities_sub')
//var aoi = ee.FeatureCollection('users/apetrov/znamensk')

// Форматирование дат - добавить ведущие нули (нужно ли?)
function zeroPad(num, places) {
  var zero = places - num.toString().length + 1;
  return Array(+(zero > 0 && zero)).join("0") + num;
}

// Маскирование облаков
var filterCloudSentinel2 = function(img) {
  /*
  Bitmask for QA60
    Bit 10: Opaque clouds
        0: No opaque clouds
        1: Opaque clouds present
    Bit 11: Cirrus clouds
        0: No cirrus clouds
        1: Cirrus clouds present
  */
  var quality = img.select('QA60').int();
  var cloudBit = ee.Number(1024);    // ee.Number(2).pow(10);
  var cirrusBit = ee.Number(2048);  // ee.Number(2).pow(11);
  
  var cloudFree = quality.bitwiseAnd(cloudBit).eq(0);
  var cirrusFree = quality.bitwiseAnd(cirrusBit).eq(0);
  var clear = cloudFree.bitwiseAnd(cirrusFree);
  
  return img.updateMask(clear);
};

// Расчёт NDVI
function calcNDVI(img){
  return img.expression('(b("B8") - b("B4")) / (b("B8") + b("B4"))').rename('NDVI');
}

// Подсчёт площади NDVI выше заданного порога (value)
function calcNdviArea(img,value,area){
    var ndviArea = img
      .gte(value) // Маскирование по пороговому значению
      .multiply(ee.Image.pixelArea()) // Считаем площадь немаскированных пикселей
      .rename('ndviArea');
      
    var stats = ndviArea.reduceRegion({
      reducer: ee.Reducer.sum(), 
      geometry: area, 
      scale: 20,
    }); // Суммируем площадь
    
    var ndvi_area_ha = ee.Number(stats.get('ndviArea')) // Суммарная площадь -> Число
      .divide(10000) // м2 -> га
      .format('%.2f'); // Форматирование до 2 знаков после запятой
   
    return(ndvi_area_ha);
}

// Рассчёт перцентилей NDVI
function createMediansNDVI(collection,aoi, year, cloud_treschold, beginMonth, endMonth){
  var imgList = [];
    var begin_date = '01'+zeroPad(beginMonth, 2)+year;
    var end_date = ((new Date(year, endMonth, 0)).getDate()).toString()+zeroPad(endMonth, 2)+year;
    var begin_date_f = year+'-'+zeroPad(beginMonth, 2)+'-01';
    var end_date_f = year+'-'+zeroPad(endMonth, 2)+'-'+((new Date(year, endMonth, 0)).getDate()).toString();
    //print(begin_date,current_date);
    
    var filterParams = collection
      .filterBounds(aoi) // Фильтр по экстенту
      .filterDate(begin_date_f, end_date_f) // Фильтр по месяцам
      .filterMetadata('CLOUDY_PIXEL_PERCENTAGE','less_than', cloud_treschold) // Фильтр по облачности (метадата)
      .map(filterCloudSentinel2) // Маскирование облаков
      .map(calcNDVI) // Рассчёт NDVI для каждого снимка в коллекции
      .map(function(image){return image.clip(aoi)}); // Обрезка NDVI по границе города

//  Попиксельно считаем медиану на NDVI
    var percentile = filterParams
      .select('NDVI')
      .reduce(ee.Reducer.percentile([50])); //  Расчёт через перцентиль - разницы в производительности с медианой нет, зато можно "поиграть" значением

    var ndvi_50_area = calcNdviArea(percentile, 0.50, aoi)
    var ndvi_70_area = calcNdviArea(percentile, 0.70, aoi)
    var ndvi_75_area = calcNdviArea(percentile, 0.75, aoi)
    var ndvi_80_area = calcNdviArea(percentile, 0.80, aoi)
    
    var ndvi = [ndvi_50_area, ndvi_70_area, ndvi_75_area, ndvi_80_area];
//    Map.addLayer(percentile.clip(aoi).select('NDVI_p50'), {min: 0.5, max: 1, palette: ['white', 'green']}, 'NDVI-percent-70-'+begin_date+'-'+end_date);

  return(ndvi);
}


// This function computes the feature's geometry area and adds it as a property.
var addNdvi = function(feature) {
  var ndvi = createMediansNDVI(collection,feature.geometry(), 2020, 20, 5, 9);

  return feature.set({
    ndvi_50_ha: ndvi[0],
    ndvi_70_ha: ndvi[1],
    ndvi_75_ha: ndvi[2],
    ndvi_80_ha: ndvi[3]
  });
};


// Map the area getting function over the FeatureCollection.
var calculatedAreas = aoi
  .sort('id_gis') // Сортировка таблицы по id_gis
//  .filter(ee.Filter.neq('id_gis', 1100)) // Превентивно отбрасываем Знаменск!!!
//  .filter('id_gis == 1068') // Фильтр по id_gis
  .map(addNdvi);


// Print the first feature from the collection with the added property.
//print('Features:', calculatedAreas);


// Export to Google Drive
Export.table.toDrive({
  collection: calculatedAreas,
  description: 'ndvi_stat',
  folder: 'EarthEngine',
  fileNamePrefix: 'ndvi_stat',
  fileFormat: 'GeoJSON',
  selectors: ('id, id_gis, city, ndvi_50_ha, ndvi_70_ha, ndvi_75_ha, ndvi_80_ha')
});



