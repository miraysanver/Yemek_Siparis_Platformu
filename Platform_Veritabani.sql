
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