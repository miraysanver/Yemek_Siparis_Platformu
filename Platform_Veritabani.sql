
CREATE TABLE Kullanicilar (
    KullaniciID INT IDENTITY(1,1), 
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    Eposta VARCHAR(100) NOT NULL,
    Telefon VARCHAR(15) NOT NULL,
    Rol VARCHAR(20) NOT NULL, 
    Bakiye DECIMAL(10, 2) DEFAULT 0.00,
    IsVerified BIT DEFAULT 0, 
    IsActive INT DEFAULT 1, 
    
    CONSTRAINT PK_Kullanicilar PRIMARY KEY (KullaniciID), 
    CONSTRAINT UQ_KullaniciEposta UNIQUE (Eposta), 
    CONSTRAINT UQ_KullaniciTelefon UNIQUE (Telefon), 
    CONSTRAINT CHK_KullaniciBakiye CHECK (Bakiye >= 0)
);

CREATE TABLE Restoranlar (
    RestoranID INT IDENTITY(1,1), 
    RestoranAdi VARCHAR(100) NOT NULL,
    Adres TEXT NOT NULL,
    RestoranPuani DECIMAL(2, 1) DEFAULT 1.0,
    IsActive INT DEFAULT 1,
    
    CONSTRAINT PK_Restoranlar PRIMARY KEY (RestoranID), 
    CONSTRAINT CHK_RestoranPuani CHECK (RestoranPuani BETWEEN 1.0 AND 5.0) 
);

CREATE TABLE Urunler (
    UrunID INT IDENTITY(1,1), 
    RestoranID INT NOT NULL,  
    UrunAdi VARCHAR(100) NOT NULL,
    Acýklama TEXT,
    Fiyat DECIMAL(10, 2) NOT NULL,
    IsActive INT DEFAULT 1,   

    CONSTRAINT PK_Urunler PRIMARY KEY (UrunID),
    
    CONSTRAINT FK_Urunler_Restoranlar FOREIGN KEY (RestoranID) 
        REFERENCES Restoranlar(RestoranID),
        
    CONSTRAINT CHK_UrunFiyat CHECK (Fiyat > 0)
);

IF OBJECT_ID('dbo.Bagislar', 'U') IS NOT NULL DROP TABLE dbo.Bagislar;
IF OBJECT_ID('dbo.AskidaHavuz', 'U') IS NOT NULL DROP TABLE dbo.AskidaHavuz;
GO

CREATE TABLE AskidaHavuz (
    HavuzID INT IDENTITY(1,1),
    ToplamBakiye DECIMAL(10, 2) DEFAULT 0.00,
    SonGuncellemeTarihi DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_AskidaHavuz PRIMARY KEY (HavuzID),
    CONSTRAINT CHK_HavuzToplamBakiye CHECK (ToplamBakiye >= 0)
);
GO

CREATE TABLE Bagislar (
    BagisID INT IDENTITY(1,1),
    BagisciID INT NULL, 
    BagisMiktar DECIMAL(10, 2) NOT NULL,
    IsAnonymous BIT DEFAULT 0,  
    BagisTarihi DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Bagislar PRIMARY KEY (BagisID),
    
    CONSTRAINT FK_Bagislar_Kullanicilar FOREIGN KEY (BagisciID) 
        REFERENCES Kullanicilar(KullaniciID),
        
    CONSTRAINT CHK_BagisMiktar CHECK (BagisMiktar > 0)
);
GO

INSERT INTO AskidaHavuz (ToplamBakiye) VALUES (0.00);
GO

IF OBJECT_ID('dbo.SiparisDetaylari', 'U') IS NOT NULL DROP TABLE dbo.SiparisDetaylari;
IF OBJECT_ID('dbo.Siparisler', 'U') IS NOT NULL DROP TABLE dbo.Siparisler;
GO

CREATE TABLE Siparisler (
    SiparisID INT IDENTITY(1,1),
    MusteriID INT NOT NULL,       
    RestoranID INT NOT NULL,      
    ToplamTutar DECIMAL(10, 2) NOT NULL,
    OdemeYontemi VARCHAR(30) NOT NULL, 
    SiparisDurumu VARCHAR(30) DEFAULT 'Hazirlaniyor', 
    SiparisTarihi DATETIME DEFAULT GETDATE(),

    CONSTRAINT PK_Siparisler PRIMARY KEY (SiparisID),
    
    CONSTRAINT FK_Siparisler_Kullanicilar FOREIGN KEY (MusteriID) 
        REFERENCES Kullanicilar(KullaniciID),
    CONSTRAINT FK_Siparisler_Restoranlar FOREIGN KEY (RestoranID) 
        REFERENCES Restoranlar(RestoranID),
        
    CONSTRAINT CHK_SiparisToplamTutar CHECK (ToplamTutar > 0)
);
GO

CREATE TABLE SiparisDetaylari (
    SiparisDetayID INT IDENTITY(1,1),
    SiparisID INT NOT NULL,      
    UrunID INT NOT NULL,          
    Adet INT NOT NULL DEFAULT 1,
    BirimFiyat DECIMAL(10, 2) NOT NULL,

    CONSTRAINT PK_SiparisDetaylari PRIMARY KEY (SiparisDetayID),
    
    CONSTRAINT FK_SiparisDetaylari_Siparisler FOREIGN KEY (SiparisID) 
        REFERENCES Siparisler(SiparisID),
    CONSTRAINT FK_SiparisDetaylari_Urunler FOREIGN KEY (UrunID) 
        REFERENCES Urunler(UrunID),
        
    CONSTRAINT CHK_SDetayAdet CHECK (Adet > 0),
    CONSTRAINT CHK_SDetayBirimFiyat CHECK (BirimFiyat > 0)
);
GO

GO
CREATE TRIGGER TRG_BagisSonrasiHavuzGuncelle
ON Bagislar
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EklenenMiktar DECIMAL(10,2);
    SELECT @EklenenMiktar = BagisMiktar FROM inserted;
    
    UPDATE AskidaHavuz
    SET ToplamBakiye = ToplamBakiye + @EklenenMiktar,
        SonGuncellemeTarihi = GETDATE()
    WHERE HavuzID = 1;
END;
GO

CREATE TRIGGER TRG_AskidaSiparisHavuzDus
ON Siparisler
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SiparisTutari DECIMAL(10,2);
    DECLARE @OdemeTipi VARCHAR(30);
    
    SELECT @SiparisTutari = ToplamTutar, @OdemeTipi = OdemeYontemi FROM inserted;
    

    IF @OdemeTipi = 'AskidaYemek'
    BEGIN
        DECLARE @MevcutHavuz DECIMAL(10,2);
        SELECT @MevcutHavuz = ToplamBakiye FROM AskidaHavuz WHERE HavuzID = 1;
        
        IF @MevcutHavuz >= @SiparisTutari
        BEGIN
            UPDATE AskidaHavuz
            SET ToplamBakiye = ToplamBakiye - @SiparisTutari,
                SonGuncellemeTarihi = GETDATE()
            WHERE HavuzID = 1;
        END
        ELSE
        BEGIN
            RAISERROR('Hata: Askýda yemek havuzunda yeterli bakiye bulunmamaktadýr!', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

GO

-- 20 ADET ANLAMLI KULLANICI EKLEME (Müþteriler, Kuryeler, Yetkililer)
INSERT INTO Kullanicilar (Ad, Soyad, Eposta, Telefon, Rol, Bakiye, IsVerified, IsActive) VALUES
('Elanur', 'Çiftçi', 'elanur.ciftci@gmail.com', '05321111111', 'Musteri', 250.00, 0, 1),
('Miray', 'Aslan', 'miray.aslan@gmail.com', '05322222222', 'Musteri', 500.00, 0, 1),
('Can', 'Demir', 'can.demir@gmail.com', '05323333333', 'Musteri', 50.00, 0, 1),
('Merve', 'Kaya', 'merve.kaya@gmail.com', '05324444444', 'Musteri', 0.00, 1, 1), -- Doðrulanmýþ Ýhtiyaç Sahibi
('Gamze', 'Özaydýn', 'gamze.ozaydin@gmail.com', '05325555555', 'Musteri', 15.00, 1, 1),  -- Doðrulanmýþ Ýhtiyaç Sahibi
('Eda', 'Þahin', 'eda.sahin@gmail.com', '05326666666', 'Musteri', 750.00, 0, 1),
('Hasan', 'Yýldýz', 'hasan.yildiz@gmail.com', '05327777777', 'Musteri', 120.00, 0, 1),
('Zeynep Naz', 'Aþan', 'zeynep.naz.asan@gmail.com', '05328888888', 'Musteri', 0.00, 1, 1), -- Doðrulanmýþ Ýhtiyaç Sahibi
('Onur', 'Arslan', 'onur.arslan@gmail.com', '05329999999', 'Musteri', 340.00, 0, 1),
('Ramazan', 'Þanver', 'ramazan.sanver@gmail.com', '05331111111', 'Musteri', 1000.00, 0, 1),
('Emre', 'Kurt', 'emre.kurt@gmail.com', '05332222222', 'Musteri', 45.00, 0, 1),
('Pelýn', 'Ay', 'pelin.ay@gmail.com', '05333333333', 'Musteri', 0.00, 1, 1),       -- Doðrulanmýþ Ýhtiyaç Sahibi
('Emine', 'Tebelleþ', 'emine.tebelles@gmail.com', '05334444444', 'Musteri', 150.00, 0, 1),
('Gökhan', 'Öztürk', 'gokhan.ozturk@gmail.com', '05335555555', 'Musteri', 60.00, 0, 1),
('Büþra', 'Aðdað', 'busra.agdag@gmail.com', '05336666666', 'Musteri', 0.00, 1, 1),       -- Doðrulanmýþ Ýhtiyaç Sahibi
('Murat', 'Tekin', 'murat.tekin@gmail.com', '05337777777', 'RestoranYetkilisi', 0.00, 0, 1),
('Ayþenaz', 'Kocatürk', 'aysenaz.kocaturk@gmail.com', '05338888888', 'RestoranYetkilisi', 0.00, 0, 1),
('Ali', 'Yavuz', 'ali.yavuz@gmail.com', '05339999999', 'Kurye', 0.00, 0, 1),
('Mehmet', 'Eren', 'mehmet.eren@gmail.com', '05341111111', 'Kurye', 0.00, 0, 1),
('Fatma', 'Bulut', 'fatma.bulut@gmail.com', '05342222222', 'Kurye', 0.00, 0, 1);
GO

-- 5 ADET ANLAMLI RESTORAN EKLEME
INSERT INTO Restoranlar (RestoranAdi, Adres, RestoranPuani, IsActive) VALUES
('Mosh Burger', 'Yalova Çýnarcýk No:12', 4.5, 1),
('Yýldýz Lahmacun', 'Yalova Merkez No:45', 4.2, 1),
('Elf Cafe', 'Yalova Çiftlikköy No:88', 3.9, 1),
('Boston Cafe', 'Yalova Kadýköy No:3', 4.7, 1),
('Yeþil Baklava', 'Yalova Merkez No:7', 4.8, 1);
GO